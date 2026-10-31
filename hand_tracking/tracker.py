#!/usr/bin/env python3
"""
Real-time Hand Tracking Server for Godot Claw Machine Game.
Uses MediaPipe Hand Landmarker via OpenCV webcam feed and transmits
normalized coordinates and gestures over WebSocket to Godot on ws://127.0.0.1:9099.
"""

import sys
import os
import time
import json
import asyncio
import math
import numpy as np

# Ensure dependencies are available
try:
    import cv2
    import websockets
    import mediapipe as mp
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
except ImportError as e:
    print(f"Error importing required libraries: {e}")
    print("Please install requirements: pip install -r requirements.txt")
    sys.exit(1)

PORT = 9099
HOST = "127.0.0.1"
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hand_landmarker.task")

connected_clients = set()
latest_payload = {
    "type": "hand_tracking",
    "connected": True,
    "camera_active": False,
    "hand_detected": False,
    "confidence": 0.0,
    "x": 0.5,
    "y": 0.5,
    "z": 0.0,
    "hand_scale": 0.2,
    "pinching": False,
    "pinch_distance": 1.0,
    "open_palm": False,
    "tracking_timestamp": int(time.time() * 1000)
}

# Exponential smoothing filter
smoothed_x = 0.5
smoothed_y = 0.5
smoothed_z = 0.0
alpha = 0.4  # Smoothing factor (higher = more responsive, lower = smoother)

async def ws_handler(websocket):
    print(f"[Tracker] Client connected: {websocket.remote_address}")
    connected_clients.add(websocket)
    try:
        async for message in websocket:
            # Handle incoming commands if any (e.g. calibration or ping)
            try:
                data = json.loads(message)
                if data.get("cmd") == "ping":
                    await websocket.send(json.dumps({"type": "pong", "time": time.time()}))
            except Exception:
                pass
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        connected_clients.remove(websocket)
        print(f"[Tracker] Client disconnected: {websocket.remote_address}")

def compute_distance(p1, p2):
    return math.sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2 + (p1.z - p2.z)**2)

def compute_2d_distance(p1, p2):
    return math.sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2)

async def tracker_loop():
    global latest_payload, smoothed_x, smoothed_y, smoothed_z

    if not os.path.exists(MODEL_PATH):
        print(f"[Tracker Error] Model file not found at {MODEL_PATH}")
        return

    base_options = python.BaseOptions(model_asset_path=MODEL_PATH)
    options = vision.HandLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.IMAGE,
        num_hands=1,
        min_hand_detection_confidence=0.5,
        min_hand_presence_confidence=0.5,
        min_tracking_confidence=0.5
    )

    try:
        landmarker = vision.HandLandmarker.create_from_options(options)
    except Exception as e:
        print(f"[Tracker Error] Failed to initialize MediaPipe landmarker: {e}")
        return

    print("[Tracker] Attempting to open webcam (index 0)...")
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[Tracker Warning] Default webcam 0 not accessible. Will retry index 1...")
        cap = cv2.VideoCapture(1)

    camera_open = cap.isOpened()
    if camera_open:
        print("[Tracker] Webcam successfully opened!")
    else:
        print("[Tracker Warning] No webcam available. Tracking server will run in standby mode.")

    pinch_active = False

    while True:
        now_ms = int(time.time() * 1000)

        if not camera_open or not cap.isOpened():
            # If camera is not available, report status
            latest_payload = {
                "type": "hand_tracking",
                "connected": True,
                "camera_active": False,
                "hand_detected": False,
                "confidence": 0.0,
                "x": 0.5,
                "y": 0.5,
                "z": 0.0,
                "hand_scale": 0.2,
                "pinching": False,
                "pinch_distance": 1.0,
                "open_palm": False,
                "tracking_timestamp": now_ms
            }
            if connected_clients:
                msg = json.dumps(latest_payload)
                await asyncio.gather(*[client.send(msg) for client in connected_clients], return_exceptions=True)
            await asyncio.sleep(0.1)
            continue

        ret, frame = cap.read()
        if not ret:
            await asyncio.sleep(0.01)
            continue

        # Flip horizontally for intuitive selfie mirror view
        frame = cv2.flip(frame, 1)
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)

        detection_result = landmarker.detect(mp_image)

        if detection_result.hand_landmarks and len(detection_result.hand_landmarks) > 0:
            landmarks = detection_result.hand_landmarks[0]

            # Key landmarks
            wrist = landmarks[0]
            thumb_cmc = landmarks[1]
            thumb_tip = landmarks[4]
            index_mcp = landmarks[5]
            index_pip = landmarks[6]
            index_tip = landmarks[8]
            middle_mcp = landmarks[9]
            middle_tip = landmarks[12]
            ring_mcp = landmarks[13]
            ring_tip = landmarks[16]
            pinky_mcp = landmarks[17]
            pinky_tip = landmarks[20]

            # Hand scale metric: distance from wrist to middle finger knuckle (MCP)
            hand_scale = compute_distance(wrist, middle_mcp)
            if hand_scale < 0.01:
                hand_scale = 0.01

            # Palm center estimation
            palm_x = (wrist.x + index_mcp.x + middle_mcp.x + pinky_mcp.x) / 4.0
            palm_y = (wrist.y + index_mcp.y + middle_mcp.y + pinky_mcp.y) / 4.0
            palm_z = (wrist.z + index_mcp.z + middle_mcp.z + pinky_mcp.z) / 4.0

            # Forward/backward estimate (z coordinate from landmarks + hand_scale)
            # When hand is closer to camera, hand_scale is larger
            # Map palm_x and palm_y to [0.0, 1.0]
            raw_x = palm_x
            raw_y = palm_y
            raw_z = palm_z

            # Smooth positions with adaptive alpha for instant response and steady hold
            motion_dist = float(np.hypot(raw_x - smoothed_x, raw_y - smoothed_y))
            dyn_alpha = float(np.clip(0.60 + motion_dist * 4.0, 0.60, 0.95))
            smoothed_x = smoothed_x + dyn_alpha * (raw_x - smoothed_x)
            smoothed_y = smoothed_y + dyn_alpha * (raw_y - smoothed_y)
            smoothed_z = smoothed_z + dyn_alpha * (raw_z - smoothed_z)

            # Normalized pinch distance relative to hand scale
            raw_pinch_dist = compute_distance(thumb_tip, index_tip)
            norm_pinch_dist = raw_pinch_dist / hand_scale

            # Hysteresis for pinch detection
            if not pinch_active and norm_pinch_dist < 0.40:
                pinch_active = True
            elif pinch_active and norm_pinch_dist > 0.55:
                pinch_active = False

            # Open palm detection: all fingertips extended away from wrist
            thumb_ext = compute_distance(thumb_tip, wrist) > compute_distance(thumb_cmc, wrist)
            index_ext = compute_distance(index_tip, wrist) > compute_distance(index_pip, wrist)
            middle_ext = compute_distance(middle_tip, wrist) > compute_distance(middle_mcp, wrist)
            ring_ext = compute_distance(ring_tip, wrist) > compute_distance(ring_mcp, wrist)
            pinky_ext = compute_distance(pinky_tip, wrist) > compute_distance(pinky_mcp, wrist)
            is_open_palm = index_ext and middle_ext and ring_ext and pinky_ext and not pinch_active

            # Render clear view of webcam with annotated hand skeleton
            preview_img = cv2.resize(frame, (200, 140))
            # Draw hand skeleton connections
            connections = [
                (0, 1), (1, 2), (2, 3), (3, 4), # Thumb
                (0, 5), (5, 6), (6, 7), (7, 8), # Index
                (5, 9), (9, 10), (10, 11), (11, 12), # Middle
                (9, 13), (13, 14), (14, 15), (15, 16), # Ring
                (13, 17), (17, 18), (18, 19), (19, 20), # Pinky
                (0, 17) # Palm base
            ]
            h, w = 140, 200
            for p1_i, p2_i in connections:
                pt1 = (int(landmarks[p1_i].x * w), int(landmarks[p1_i].y * h))
                pt2 = (int(landmarks[p2_i].x * w), int(landmarks[p2_i].y * h))
                cv2.line(preview_img, pt1, pt2, (0, 240, 255), 2)
                
            for lm_i, lm in enumerate(landmarks):
                pt = (int(lm.x * w), int(lm.y * h))
                color = (0, 255, 0) if lm_i in [4, 8] else (255, 200, 0)
                radius = 4 if lm_i in [4, 8] else 2
                cv2.circle(preview_img, pt, radius, color, -1)
                
            # If pinching, draw connection circle between thumb and index
            if pinch_active:
                p_thumb = (int(thumb_tip.x * w), int(thumb_tip.y * h))
                p_index = (int(index_tip.x * w), int(index_tip.y * h))
                mid = ((p_thumb[0] + p_index[0]) // 2, (p_thumb[1] + p_index[1]) // 2)
                cv2.circle(preview_img, mid, 8, (0, 0, 255), 2)
                cv2.putText(preview_img, "PINCH", (mid[0] + 10, mid[1] - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 255), 1)

            # Encode as JPEG base64
            _, buf = cv2.imencode(".jpg", preview_img, [cv2.IMWRITE_JPEG_QUALITY, 65])
            import base64
            b64_frame = base64.b64encode(buf).decode("utf-8")

            latest_payload = {
                "type": "hand_tracking",
                "connected": True,
                "camera_active": True,
                "hand_detected": True,
                "confidence": 0.95,
                "x": float(np.clip(smoothed_x, 0.0, 1.0)),
                "y": float(np.clip(smoothed_y, 0.0, 1.0)),
                "z": float(smoothed_z),
                "hand_scale": float(hand_scale),
                "pinching": bool(pinch_active),
                "pinch_distance": float(norm_pinch_dist),
                "open_palm": bool(is_open_palm),
                "tracking_timestamp": now_ms,
                "preview_image": b64_frame
            }
        else:
            pinch_active = False
            # Render webcam preview even when looking for hand
            preview_img = cv2.resize(frame, (200, 140))
            cv2.putText(preview_img, "Looking for hand...", (25, 75), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 220, 255), 1)
            _, buf = cv2.imencode(".jpg", preview_img, [cv2.IMWRITE_JPEG_QUALITY, 55])
            import base64
            b64_frame = base64.b64encode(buf).decode("utf-8")

            latest_payload = {
                "type": "hand_tracking",
                "connected": True,
                "camera_active": True,
                "hand_detected": False,
                "confidence": 0.0,
                "x": float(smoothed_x),
                "y": float(smoothed_y),
                "z": float(smoothed_z),
                "hand_scale": 0.2,
                "pinching": False,
                "pinch_distance": 1.0,
                "open_palm": False,
                "tracking_timestamp": now_ms,
                "preview_image": b64_frame
            }

        if connected_clients:
            msg = json.dumps(latest_payload)
            await asyncio.gather(*[client.send(msg) for client in connected_clients], return_exceptions=True)

        # 30-60 FPS cap
        await asyncio.sleep(0.016)

    if cap.isOpened():
        cap.release()

async def main():
    print(f"=== Starting Godot Hand Tracking Bridge on ws://{HOST}:{PORT} ===")
    server = await websockets.serve(ws_handler, HOST, PORT)
    tracker_task = asyncio.create_task(tracker_loop())
    await asyncio.gather(server.wait_closed(), tracker_task)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[Tracker] Shutting down cleanly.")

