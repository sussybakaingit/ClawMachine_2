# Claw Machine Hand Tracker Bridge

This component provides real-time webcam hand tracking using MediaPipe Hand Landmarker and transmits normalized 3D hand coordinates and recognized gestures (Pinch, Open Palm) via WebSocket to the Godot Claw Machine game on `ws://127.0.0.1:9099`.

## Setup & Running

1. Activate or create a Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. Run the tracker:
   ```bash
   ./tracker.py
   # or: python3 tracker.py
   ```

3. When the Godot game starts, it connects automatically to `ws://127.0.0.1:9099`.
If the tracker or webcam is not running, the game gracefully switches to Keyboard Fallback mode without interruption.

