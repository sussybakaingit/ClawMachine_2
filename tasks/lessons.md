# Lessons & Anti-Patterns

## 1. Area3D Triggers Require CollisionShape3D
- **Symptom:** Area3D signals like `body_entered` never fire even when bodies clearly enter the visual region.
- **Root Cause:** An `Area3D` node in Godot will not detect any collisions or overlaps unless it has a child `CollisionShape3D` or `CollisionPolygon3D` with a valid shape and appropriate `collision_mask`.
- **Rule:** Whenever creating an `Area3D` trigger (e.g., delivery chute, grab area, kill plane), always verify that a child `CollisionShape3D` is attached and `collision_mask` includes the target bodies' layer. Also include an algorithmic spatial bounds fallback in `_process` for fail-safe game-critical scoring.

## 2. Hand Tracking Controls: Positional Mapping vs Joystick Velocity
- **Symptom:** Player moves hand to a prize, but the claw drifts past it or feels floaty/unsynced.
- **Root Cause:** Treating normalized hand coordinates `(x, y)` as velocity vectors (`pos += (hand_x - neutral_x) * dt`) requires the player to constantly return their hand to an invisible neutral center to stop moving.
- **Rule:** For hand-tracked games (especially arcade claw / 3D cursors), use direct 1:1 positional mapping (`target_pos = lerp(min, max, norm_coord)`) combined with a fast spring/lerp (`lerp(current, target, 18.0 * delta)`). When the user's hand stops, the claw stops immediately.

## 3. Clear Webcam Preview Overlay
- **Symptom:** Hand preview displays a blank dark box with sticks, making it hard to see where the physical hand is relative to the webcam view.
- **Root Cause:** Creating a blank `np.zeros` canvas instead of resizing and annotating the actual camera frame.
- **Rule:** Use `cv2.resize(frame)` as the background for landmark rendering and preview textures so the player has a clear view of their actual hand and environment.

## 4. Delivery Area & Fallback Spatial Bounds Height
- **Symptom:** At game start, the score immediately explodes to 20k+ as combo multipliers trigger on resting prizes.
- **Root Cause:** Trigger volumes and fallback spatial checks had vertical bounds (`Y < 0.92`) higher than the machine's prize floor (`Y = 0.74`), or trigger boxes that extended horizontally outside the chute dividers into the prize bed.
- **Rule:** The delivery trigger area and any spatial fallback must reside strictly BELOW the floor level (`Y < 0.65`) and strictly within the chute perimeter. In addition, toy spawners must enforce a clean margin away from the chute boundary so settled toys never overlap with the chute rim.

