# Hand-Controlled 3D Arcade Claw Machine Game

A complete, polished 3D arcade claw machine game built with Godot 4.7 Engine and powered by real-time webcam hand tracking (MediaPipe Hand Landmarker).

---

## 🕹️ Game Overview

Control a 3D arcade claw machine using your real hand in front of your webcam:
1. **Position the Claw**: Move your hand Left/Right and Up/Down (forward/backward) to steer the gantry across the prize pool.
2. **Grab**: Make a **Pinch gesture** (thumb + index fingertip) to lower the claw and grab a toy.
3. **Manual Carrying (Core Rule)**: Once lifted, you must **manually navigate** the carried toy across the cabinet to the front-left prize delivery chute!
4. **Release & Score**: Pinch or open your hand over the chute to drop the toy and earn points and combo multipliers!

---

## 🧸 3D Toy Collection (All 6 Included)

| Toy | Name | Points | Collision Model |
| :--- | :--- | :--- | :--- |
| 🤠 | **Sheriff Woody** | 150 pts | CapsuleCollider3D |
| 🏎️ | **Race Car** | 100 pts | BoxCollider3D |
| 🪖 | **TIE Pilot Helmet** | 200 pts | SphereCollider3D |
| 📦 | **Zelda Wood Chest** | 250 pts | BoxCollider3D |
| 🧸 | **Cute Teddy Bear** | 120 pts | CapsuleCollider3D |
| 🔴 | **Mystery Pokéball** | 180 pts | SphereCollider3D |

---

## 🚀 Quick Start Guide

### 1. Start the Hand Tracking Bridge (Python)
Ensure Python 3.10+ is installed:
```bash
# Set up virtual environment and install requirements
python3 -m venv venv
./venv/bin/pip install -r hand_tracking/requirements.txt

# Launch the webcam tracking server
./venv/bin/python hand_tracking/tracker.py
```
*Note: The hand tracking server broadcasts normalized hand coordinates and gestures over local WebSocket `ws://127.0.0.1:9099`.*

### 2. Launch the Game in Godot
Open and run with Godot 4.7+:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```
Or open the project directly in the Godot Editor and press **F5 (Play Project)**.

---

## ⌨️ Controls & Keyboard Fallback

The game seamlessly supports both Webcam Hand Tracking and Keyboard Fallback simultaneously:

| Action | Hand Tracking | Keyboard Fallback |
| :--- | :--- | :--- |
| **Move Claw (X / Z)** | Hand Left/Right & Up/Down | `WASD` or `Arrow Keys` |
| **Lower & Grab** | Pinch Gesture (or Open Palm) | `Spacebar` or `Enter` |
| **Manual Carrying** | Move Hand While Holding | `WASD` or `Arrow Keys` |
| **Drop in Chute** | Pinch or Release Gesture | `R` or `Spacebar` |
| **Camera 360° Orbit**| — | Right-Click + Drag (or Alt + Drag) |
| **Camera Zoom** | — | Mouse Scroll Wheel |
| **Camera Presets** | — | Top Bar Buttons (`Front`, `Side`, `Top`, `Chute`) |
| **Reset Camera** | — | `C` key or Top Bar button |
| **Pause / Resume** | — | `P` or `Escape` |

---

## ⚙️ Settings & Customization

The game includes a persistent settings menu (`user://settings.cfg`):
- **Hand Controls**: Hand sensitivity, movement smoothing, dead zone, invert horizontal, recalibrate neutral hand position, gesture threshold and cooldown.
- **Graphics**: Low / Medium / High presets, Fullscreen, V-Sync, Camera FOV (45°-90°).
- **Audio**: Procedural arcade chiptune music sequencer and synthesized SFX volume sliders, mute toggle.
- **Gameplay**: 30-second and 60-second modes, grip difficulty, tutorial toggle, persistent local high scores.

---

## 📁 Architecture

```
ClawMachine_G3/
├── Assets/                 # 3D claw machine, 6 toy models, background panorama
├── hand_tracking/
│   ├── tracker.py          # MediaPipe Hand Landmarker webcam bridge
│   ├── requirements.txt    # opencv-python, mediapipe, websockets
│   └── hand_landmarker.task# Preloaded lightweight vision model
├── scenes/
│   ├── main_menu.tscn      # Main Menu with high scores and duration selection
│   ├── main_game.tscn      # 3D Main Game world with environment and lights
│   ├── claw_machine.tscn   # Cabinet enclosure, glass, floor, delivery hole
│   ├── claw_assembly.tscn  # Articulated 3-finger claw, gantry, cable
│   ├── camera_rig.tscn     # 360-degree orbit and zoom camera rig
│   ├── settings_menu.tscn  # Tabbed persistent settings and calibration
│   └── toy_*.tscn          # Reusable physics scenes for each of the 6 toys
└── scripts/
    ├── game_manager.gd     # Round timers (30s/60s), scoring, combo system
    ├── claw_controller.gd  # Claw FSM, gantry translation, finger articulation
    ├── prize_manager.gd    # 24-toy pool procedural spawner and stabilizer
    ├── prize.gd            # RigidBody3D physics toy controller
    ├── camera_controller.gd# Smooth orbit, clamping, presets, and FOV
    ├── hand_tracking_client.gd # WebSocket client and gesture debounce
    ├── audio_manager.gd    # Synthesized retro arcade audio generator
    └── settings_manager.gd # Persistent ConfigFile manager
```

