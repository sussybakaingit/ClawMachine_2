class_name ClawController
extends Node3D

enum State {
	IDLE,
	MOVING,
	DESCENDING,
	CLOSING,
	LIFTING,
	CARRYING,
	DELIVERING,
	RELEASING,
	RETURNING,
	PAUSED
}

var current_state: State = State.IDLE
var target_state: State = State.IDLE

# Mechanical Assembly Node References
@onready var gantry_x: Node3D = $GantryX
@onready var carriage_z: Node3D = $GantryX/CarriageZ
@onready var cable_mesh: MeshInstance3D = $GantryX/CarriageZ/CableMesh
@onready var claw_head: Node3D = $GantryX/CarriageZ/ClawHead
@onready var grab_area: Area3D = $GantryX/CarriageZ/ClawHead/GrabArea

# Fingers for procedural articulation
@onready var finger_1: Node3D = $GantryX/CarriageZ/ClawHead/Fingers/Finger1
@onready var finger_2: Node3D = $GantryX/CarriageZ/ClawHead/Fingers/Finger2
@onready var finger_3: Node3D = $GantryX/CarriageZ/ClawHead/Fingers/Finger3

# Movement Bounds (Machine Interior)
# Delivery hole is in front-left corner
const MIN_X: float = -0.36
const MAX_X: float = 0.36
const MIN_Z: float = -0.34
const MAX_Z: float = 0.36

const CHUTE_TARGET_X: float = -0.30
const CHUTE_TARGET_Z: float = 0.30

const REST_Y: float = 1.62     # High resting position
const FLOOR_Y: float = 0.82    # Lowest descent height reaching toys on bed

# Dynamic State
var carried_prize = null
var finger_openness: float = 1.0 # 1.0 = fully open, 0.0 = fully closed
var current_pos_x: float = 0.0
var current_pos_z: float = 0.0
var current_claw_y: float = REST_Y

# Speed tunables
var move_speed: float = 0.45
var descent_speed: float = 0.50
var lift_speed: float = 0.42
var finger_speed: float = 4.5

signal state_changed(new_state: State)
signal prize_grabbed(prize)
signal prize_released(prize)

func _ready():
	_update_transforms()
	set_state(State.IDLE)

func set_state(new_state: State):
	current_state = new_state
	emit_signal("state_changed", new_state)

func _physics_process(delta):
	if current_state == State.PAUSED:
		return
		
	match current_state:
		State.IDLE, State.MOVING:
			_process_manual_movement(delta)
		State.CARRYING:
			# Auto-navigate toward delivery chute when carrying a prize
			_process_auto_carrying(delta)
			_sync_carried_prize()
		State.DELIVERING:
			_process_auto_carrying(delta)
			_sync_carried_prize()
		State.DESCENDING:
			_process_descent(delta)
		State.CLOSING:
			_process_closing(delta)
		State.LIFTING:
			_process_lifting(delta)
		State.RELEASING:
			_process_releasing(delta)
		State.RETURNING:
			_process_returning(delta)

	_update_fingers(delta)
	_update_transforms()

func _process_manual_movement(delta):
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var ht_client = get_node_or_null("/root/HandTrackingClient")
	
	# Check keyboard input first for seamless fallback / manual nudge
	var kb_x = 0.0
	var kb_z = 0.0
	if s_mgr == null or s_mgr.keyboard_fallback_enabled:
		kb_x = Input.get_axis("claw_left", "claw_right")
		kb_z = Input.get_axis("claw_forward", "claw_backward")
		
	var is_keyboard_active = abs(kb_x) > 0.05 or abs(kb_z) > 0.05
	var is_moving = false
	
	if is_keyboard_active:
		# Direct keyboard gantry drive
		var max_spd = s_mgr.max_claw_speed if s_mgr else 0.5
		current_pos_x += kb_x * move_speed * max_spd * delta * 2.8
		current_pos_z += kb_z * move_speed * max_spd * delta * 2.8
		is_moving = true
	elif ht_client and ht_client.hand_detected:
		# Direct 1:1 positional synchronization with hand coordinates
		var target_pos = ht_client.get_mapped_claw_position(MIN_X, MAX_X, MIN_Z, MAX_Z)
		var follow_speed = 18.0 # Responsive spring interpolation
		var weight = clamp(follow_speed * delta, 0.0, 1.0)
		
		var dx = target_pos.x - current_pos_x
		var dz = target_pos.y - current_pos_z
		if Vector2(dx, dz).length() > 0.005:
			current_pos_x = lerp(current_pos_x, target_pos.x, weight)
			current_pos_z = lerp(current_pos_z, target_pos.y, weight)
			is_moving = true
			
	current_pos_x = clamp(current_pos_x, MIN_X, MAX_X)
	current_pos_z = clamp(current_pos_z, MIN_Z, MAX_Z)
	
	if is_moving:
		if current_state == State.IDLE:
			set_state(State.MOVING)
	else:
		if current_state == State.MOVING:
			set_state(State.IDLE)

func start_grab():
	if current_state == State.IDLE or current_state == State.MOVING:
		var a_mgr = get_node_or_null("/root/AudioManager")
		if a_mgr: a_mgr.play_sound("drop")
		set_state(State.DESCENDING)

func start_release():
	if current_state == State.CARRYING:
		var a_mgr = get_node_or_null("/root/AudioManager")
		if a_mgr: a_mgr.play_sound("drop")
		set_state(State.RELEASING)

func _process_descent(delta):
	finger_openness = move_toward(finger_openness, 1.0, finger_speed * delta)
	current_claw_y = move_toward(current_claw_y, FLOOR_Y, descent_speed * delta)
	
	# Check if reached bottom or hit toys
	if current_claw_y <= FLOOR_Y + 0.01:
		var a_mgr = get_node_or_null("/root/AudioManager")
		if a_mgr: a_mgr.play_sound("grab")
		set_state(State.CLOSING)

func _process_closing(delta):
	finger_openness = move_toward(finger_openness, 0.0, finger_speed * delta)
	
	if finger_openness <= 0.05:
		# Attempt grab on overlapping prize
		_attempt_grab()
		set_state(State.LIFTING)

func _attempt_grab():
	carried_prize = null
	var candidates: Array = []
	for body in grab_area.get_overlapping_bodies():
		if body.has_method("set_grabbed") and not body.get("is_delivered"):
			candidates.append(body)
			
	# Fallback distance search across prize pool if GrabArea missed due to physics frame timing
	if candidates.is_empty():
		var p_mgr = get_parent().get_node_or_null("PrizeManager") if get_parent() else null
		if p_mgr and "spawned_toys" in p_mgr:
			for toy in p_mgr.spawned_toys:
				if is_instance_valid(toy) and not toy.get("is_delivered"):
					var d = toy.global_position.distance_to(claw_head.global_position)
					if d < 0.28:
						candidates.append(toy)

	if candidates.size() > 0:
		# Pick closest toy to claw center
		var closest = candidates[0]
		var min_d = closest.global_position.distance_to(claw_head.global_position)
		for c in candidates:
			var d = c.global_position.distance_to(claw_head.global_position)
			if d < min_d:
				min_d = d
				closest = c
				
		# Generous grip success rate for fun, satisfying gameplay
		var s_mgr = get_node_or_null("/root/SettingsManager")
		var diff = s_mgr.grab_difficulty if s_mgr else 0.95
		var success_roll = randf()
		if success_roll <= diff:
			carried_prize = closest
			carried_prize.set_grabbed(true)
			carried_prize.grab_offset = Vector3(0.0, -0.12, 0.0)
			var a_mgr = get_node_or_null("/root/AudioManager")
			if a_mgr: a_mgr.play_sound("success")
			emit_signal("prize_grabbed", carried_prize)
		else:
			var a_mgr = get_node_or_null("/root/AudioManager")
			if a_mgr: a_mgr.play_sound("fail")
	else:
		var a_mgr = get_node_or_null("/root/AudioManager")
		if a_mgr: a_mgr.play_sound("fail")

func _process_lifting(delta):
	current_claw_y = move_toward(current_claw_y, REST_Y, lift_speed * delta)
	_sync_carried_prize()
	
	if current_claw_y >= REST_Y - 0.01:
		if carried_prize:
			set_state(State.CARRYING)
		else:
			set_state(State.IDLE)

func _process_auto_carrying(delta):
	# Smoothly transport claw directly above delivery hole
	var transport_speed = move_speed * 1.5
	current_pos_x = move_toward(current_pos_x, CHUTE_TARGET_X, transport_speed * delta)
	current_pos_z = move_toward(current_pos_z, CHUTE_TARGET_Z, transport_speed * delta)
	
	var dist_to_chute = Vector2(current_pos_x - CHUTE_TARGET_X, current_pos_z - CHUTE_TARGET_Z).length()
	if dist_to_chute < 0.02:
		# Directly above the prize chute: auto-release toy
		start_release()

func _process_releasing(delta):
	finger_openness = move_toward(finger_openness, 1.0, finger_speed * delta)
	
	if carried_prize and finger_openness >= 0.7:
		var p = carried_prize
		carried_prize = null
		p.set_grabbed(false)
		emit_signal("prize_released", p)
		var a_mgr = get_node_or_null("/root/AudioManager")
		if a_mgr: a_mgr.play_sound("click")
		
	if finger_openness >= 0.98:
		set_state(State.IDLE)

func _process_returning(delta):
	current_claw_y = move_toward(current_claw_y, REST_Y, lift_speed * delta)
	if current_claw_y >= REST_Y - 0.01:
		set_state(State.IDLE)

func _sync_carried_prize():
	if carried_prize and is_instance_valid(carried_prize) and claw_head:
		carried_prize.global_position = claw_head.global_position + carried_prize.grab_offset

func _update_fingers(delta):
	# Animate finger rotation: 0.0 = fully closed (pointed downward inward), 1.0 = fully open (flared outward)
	var angle = lerp(0.0, 0.65, finger_openness)
	if finger_1:
		finger_1.rotation.z = angle
	if finger_2:
		finger_2.rotation.z = -angle
	if finger_3:
		finger_3.rotation.x = angle

func _update_transforms():
	if gantry_x:
		gantry_x.position.x = current_pos_x
	if carriage_z:
		carriage_z.position.z = current_pos_z
	if claw_head:
		claw_head.position.y = current_claw_y
	if cable_mesh:
		# Cable stretches from top ceiling (y = 1.76) down to claw_head (y = current_claw_y)
		var top_y = 1.76
		var cable_length = max(top_y - current_claw_y, 0.05)
		cable_mesh.position.y = top_y - (cable_length * 0.5)
		cable_mesh.scale.y = cable_length
