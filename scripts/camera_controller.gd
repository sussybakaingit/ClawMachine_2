class_name CameraController
extends Node3D

@export var target_node: Node3D
@export var min_distance: float = 1.3
@export var max_distance: float = 3.6
@export var default_distance: float = 2.4
@export var default_yaw: float = 0.0
@export var default_pitch: float = -18.0

# Dynamic follow / frame sync with claw position
@export var follow_claw_enabled: bool = true
var claw_ref: Node3D = null
var base_pivot_pos: Vector3 = Vector3(0.0, 1.35, 0.0)

var current_distance: float = 2.4
var target_distance: float = 2.4

var current_yaw: float = 0.0
var target_yaw: float = 0.0

var current_pitch: float = -18.0
var target_pitch: float = -18.0

var is_dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

func _ready():
	base_pivot_pos = position
	reset_camera()

func set_claw_target(claw: Node3D):
	claw_ref = claw

func _input(event):
	# Mouse Orbit: Right Click Drag or Left Click Drag on empty space
	if event is InputEventMouseButton:
		var s_mgr = get_node_or_null("/root/SettingsManager")
		var min_d = s_mgr.camera_min_dist if s_mgr else 1.2
		var max_d = s_mgr.camera_max_dist if s_mgr else 3.5
		
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_ALT)):
			if event.pressed:
				is_dragging = true
				last_mouse_pos = event.position
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = clamp(target_distance - 0.18, min_d, max_d)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = clamp(target_distance + 0.18, min_d, max_d)
			
	elif event is InputEventMouseMotion and is_dragging:
		var delta_pos = event.position - last_mouse_pos
		last_mouse_pos = event.position
		
		var s_mgr = get_node_or_null("/root/SettingsManager")
		var sens = (s_mgr.camera_orbit_sensitivity if s_mgr else 0.005) * 100.0
		var invert_x = -1.0 if (s_mgr and s_mgr.camera_invert_x) else 1.0
		var invert_y = -1.0 if (s_mgr and s_mgr.camera_invert_y) else 1.0
		
		target_yaw -= delta_pos.x * sens * invert_x
		target_pitch -= delta_pos.y * sens * invert_y
		target_pitch = clamp(target_pitch, -75.0, 15.0)

	# Keyboard presets & reset
	if Input.is_action_just_pressed("camera_reset"):
		reset_camera()

func _process(delta):
	# Smooth interpolation
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var smoothing = s_mgr.camera_smoothing if s_mgr else 8.0
	var fov_val = s_mgr.camera_fov if s_mgr else 62.0
	
	# Sync camera pivot subtly with claw movement so the claw & toys stay perfectly framed
	if follow_claw_enabled and claw_ref and is_instance_valid(claw_ref):
		var claw_x = claw_ref.get("current_pos_x") if "current_pos_x" in claw_ref else 0.0
		var claw_z = claw_ref.get("current_pos_z") if "current_pos_z" in claw_ref else 0.0
		# Gentle framing offset (0.28 scale keeps cabinet in view while focusing action)
		var desired_pivot = base_pivot_pos + Vector3(claw_x * 0.28, 0.0, claw_z * 0.22)
		position = position.lerp(desired_pivot, 5.0 * delta)
	
	current_yaw = lerp_angle(deg_to_rad(current_yaw), deg_to_rad(target_yaw), smoothing * delta)
	current_yaw = rad_to_deg(current_yaw)
	
	current_pitch = lerp(current_pitch, target_pitch, smoothing * delta)
	current_distance = lerp(current_distance, target_distance, smoothing * delta)
	
	rotation_degrees.y = current_yaw
	if pitch_pivot:
		pitch_pivot.rotation_degrees.x = current_pitch
	if camera:
		camera.position.z = current_distance
		camera.fov = fov_val

func reset_camera():
	target_distance = default_distance
	target_yaw = default_yaw
	target_pitch = default_pitch

func set_preset(preset_name: String):
	match preset_name:
		"front":
			target_yaw = 0.0
			target_pitch = -12.0
			target_distance = 2.2
		"side":
			target_yaw = -90.0
			target_pitch = -15.0
			target_distance = 2.3
		"top":
			target_yaw = 0.0
			target_pitch = -70.0
			target_distance = 2.1
		"hole":
			# Focus on prize delivery hole at front-left
			target_yaw = 35.0
			target_pitch = -30.0
			target_distance = 1.6
		"reset":
			reset_camera()
