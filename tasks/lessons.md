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

## 4. Delivery Area & Chute Bounds
- **Symptom:** Either score instantly explodes at start due to prizes outside the chute triggering delivery, or score never updates because the height filter is lower than the chute's floor plane.
- **Root Cause:** In arcade cabinets where the floor collider spans the full cabinet, toys dropped into the chute pocket land on the floor at `Y ~ 0.76` inside the walled pocket (`X < -0.18` and `Z > 0.18`). If an Area3D trigger or filter checks `Y < 0.74`, the landed toy is rejected; if it checks without horizontal bounds (`X` and `Z`), toys resting on the prize bed get falsely counted.
- **Rule:** The delivery trigger area and spatial fallback must be bounded strictly by the chute's horizontal walls (`X < -0.19` and `Z > 0.19`) and cover the height from the chute floor up to the divider rim (`Y in [0.70, 1.05]`). In addition, prize pool spawners must enforce a clean safety margin away from the chute boundary so resting toys never sit on or against the chute dividers.

## 5. Visual Asset Scaling & Metric Verification
- **Symptom:** 3D model appears gargantuan (spanning outside the level or enveloping the camera) or microscopic (fractions of a millimeter).
- **Root Cause:** Raw glTF/FBX assets from various sources have widely different root node transformations (e.g., Blender default $\times 100$, centimeters vs meters).
- **Rule:** Always measure instantiated scene world AABBs (`AABB.size`) across all interactive objects to ensure they fit within physical gameplay metrics (e.g. 10–18 cm for claw machine toys) and match their physics collision shapes.

## 6. Embedded Model Material Overrides & Background Frustum Coverage
- **Symptom:** Interior of a 3D model looks blinding chalky white, and background backdrop appears with visible cutting borders and double ghost images.
- **Root Cause:** Imported 3D models (such as `clawMachine.glb`) often embed materials with extreme emission values (e.g. 15.4 energy) or milky semi-opaque frosted glass (`albedo_color` alpha 0.34, roughness 0.5) that wash out in engine lighting. Simultaneously, wrapping a flat 16:9 photo around a 360-degree PanoramaSky creates spherical distortion that clashes with a foreground quad.
- **Rule:** Override imported model surfaces with proper PBR properties (crystal clear transparency for glass, realistic low emission values $\le 1.0$). For flat perspective backgrounds, use a dark matching procedural sky combined with a properly scaled ($>20\text{m}$) backdrop positioned to align with the camera frustum and floor level ($Y = 0.0$).

