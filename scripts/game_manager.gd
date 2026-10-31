class_name GameManager
extends Node

enum GameMode { TIME_30 = 30, TIME_60 = 60 }
enum GameState { READY, PLAYING, ROUND_OVER, PAUSED }

var current_state: GameState = GameState.READY
var selected_duration: int = 60
var time_remaining: float = 60.0
var current_score: int = 0
var toys_delivered_count: int = 0
var combo_multiplier: int = 1

# References in Main Game
var claw_controller: Node
var prize_manager: Node
var delivery_hole_area: Area3D
var camera_controller: Node

signal score_changed(score: int, combo: int)
signal timer_updated(time_left: float)
signal prize_delivered(toy_name: String, points: int)
signal game_over(final_score: int, toys_count: int, is_new_record: bool)
signal game_state_changed(new_state: int)

func setup(claw: Node, p_mgr: Node, hole: Area3D, cam: Node):
	claw_controller = claw
	prize_manager = p_mgr
	delivery_hole_area = hole
	camera_controller = cam
	
	if delivery_hole_area:
		delivery_hole_area.body_entered.connect(_on_delivery_hole_body_entered)
		
	# Connect Hand Tracking triggers
	var ht = get_node_or_null("/root/HandTrackingClient")
	if ht:
		if not ht.grab_gesture_triggered.is_connected(_on_hand_grab_gesture):
			ht.grab_gesture_triggered.connect(_on_hand_grab_gesture)
		if not ht.release_gesture_triggered.is_connected(_on_hand_release_gesture):
			ht.release_gesture_triggered.connect(_on_hand_release_gesture)

func start_game(duration: int):
	selected_duration = duration
	time_remaining = float(duration)
	current_score = 0
	toys_delivered_count = 0
	combo_multiplier = 1
	current_state = GameState.PLAYING
	
	if prize_manager:
		prize_manager.reset_pool()
		
	if claw_controller:
		claw_controller.set_state(0) # 0 = State.IDLE
		claw_controller.current_pos_x = 0.0
		claw_controller.current_pos_z = 0.0
		
	emit_signal("score_changed", current_score, combo_multiplier)
	emit_signal("timer_updated", time_remaining)
	emit_signal("game_state_changed", current_state)

func _process(delta):
	if current_state == GameState.PLAYING:
		time_remaining -= delta
		if time_remaining <= 0.0:
			time_remaining = 0.0
			_end_round()
		emit_signal("timer_updated", time_remaining)
		
		# Failsafe prize chute detection:
		# A toy has dropped down the delivery hole only when it enters below the floor (Y < 0.65)
		# inside the chute boundaries (X < -0.20 and Z > 0.20)
		if prize_manager and "spawned_toys" in prize_manager:
			for toy in prize_manager.spawned_toys:
				if is_instance_valid(toy) and not toy.get("is_delivered"):
					var p = toy.global_position
					if p.x < -0.20 and p.z > 0.20 and p.y < 0.65:
						_on_delivery_hole_body_entered(toy)

func _unhandled_input(event):
	if current_state != GameState.PLAYING:
		return
		
	# Keyboard triggers for grab/release
	if Input.is_action_just_pressed("claw_grab"):
		_on_hand_grab_gesture()
	elif Input.is_action_just_pressed("claw_release"):
		_on_hand_release_gesture()

func _on_hand_grab_gesture():
	if current_state != GameState.PLAYING:
		return
	if claw_controller:
		claw_controller.start_grab()

func _on_hand_release_gesture():
	if current_state != GameState.PLAYING:
		return
	if claw_controller:
		claw_controller.start_release()

func _on_delivery_hole_body_entered(body: Node3D):
	if body.has_method("set_grabbed") and not body.get("is_delivered"):
		# Verify toy is down at the chute level (Y <= 0.74) and not on top of the divider or bed
		if body.global_position.y > 0.74:
			return
			
		body.set("is_delivered", true)
		toys_delivered_count += 1
		
		var toy_name = body.get("toy_name") if body.get("toy_name") else "Toy"
		var base_score = body.get("score_value") if body.get("score_value") else 100
		var pts = base_score * combo_multiplier
		current_score += pts
		combo_multiplier += 1
		
		var s_mgr = get_node_or_null("/root/SettingsManager")
		if s_mgr and body.get("toy_id"):
			s_mgr.record_toy_collected(body.get("toy_id"))
			
		var a_mgr = get_node_or_null("/root/AudioManager")
		if a_mgr:
			a_mgr.play_sound("success")
			
		emit_signal("score_changed", current_score, combo_multiplier)
		emit_signal("prize_delivered", toy_name, pts)
		
		# Animate prize collection and fade out
		var tween = create_tween()
		tween.tween_property(body, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(body.queue_free)

func _end_round():
	current_state = GameState.ROUND_OVER
	var a_mgr = get_node_or_null("/root/AudioManager")
	if a_mgr: a_mgr.play_sound("gameover")
	
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var is_record = false
	if s_mgr:
		is_record = s_mgr.record_high_score(selected_duration, current_score)
		
	emit_signal("game_over", current_score, toys_delivered_count, is_record)
	emit_signal("game_state_changed", current_state)
