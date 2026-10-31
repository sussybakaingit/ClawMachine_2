extends Node

# WebSocket Client for receiving Hand Tracking data from tracker.py
const WS_URL = "ws://127.0.0.1:9099"

var peer: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var last_connect_attempt: float = 0.0
var reconnect_interval: float = 2.0

# Current Tracking State
var camera_active: bool = false
var hand_detected: bool = false
var confidence: float = 0.0
var hand_x: float = 0.5   # Normalized 0..1 (Left to Right)
var hand_y: float = 0.5   # Normalized 0..1 (Top to Bottom)
var hand_z: float = 0.0   # Relative depth
var hand_scale: float = 0.2
var is_pinching: bool = false
var pinch_distance: float = 1.0
var is_open_palm: bool = false
var last_tracking_time: float = 0.0
var preview_texture: ImageTexture = null

# Calibrated neutral offset
var neutral_x: float = 0.5
var neutral_y: float = 0.5

# Gesture debounce / edge triggers
var prev_pinch_state: bool = false
var prev_palm_state: bool = false
var last_gesture_time: float = 0.0

signal hand_data_updated(data: Dictionary)
signal grab_gesture_triggered
signal release_gesture_triggered
signal connection_state_changed(connected: bool)

func _ready():
	_connect_to_server()

func _connect_to_server():
	peer.close()
	var err = peer.connect_to_url(WS_URL)
	if err == OK:
		pass
	else:
		is_connected_to_server = false

func _process(delta):
	peer.poll()
	var state = peer.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			emit_signal("connection_state_changed", true)
			
		while peer.get_available_packet_count() > 0:
			var packet = peer.get_packet()
			var msg_str = packet.get_string_from_utf8()
			_parse_message(msg_str)
	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		if is_connected_to_server:
			is_connected_to_server = false
			hand_detected = false
			emit_signal("connection_state_changed", false)
			
		last_connect_attempt += delta
		if last_connect_attempt >= reconnect_interval:
			last_connect_attempt = 0.0
			_connect_to_server()

func _parse_message(json_str: String):
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		return
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return
		
	if data.get("type") == "hand_tracking":
		camera_active = data.get("camera_active", false)
		hand_detected = data.get("hand_detected", false)
		confidence = data.get("confidence", 0.0)
		hand_x = data.get("x", 0.5)
		hand_y = data.get("y", 0.5)
		hand_z = data.get("z", 0.0)
		hand_scale = data.get("hand_scale", 0.2)
		is_pinching = data.get("pinching", false)
		pinch_distance = data.get("pinch_distance", 1.0)
		is_open_palm = data.get("open_palm", false)
		last_tracking_time = Time.get_ticks_msec() / 1000.0
		
		# Decode preview frame if available
		var b64_frame = data.get("preview_image", "")
		if b64_frame != "":
			var raw_bytes = Marshalls.base64_to_raw(b64_frame)
			var img = Image.new()
			var err = img.load_jpg_from_buffer(raw_bytes)
			if err == OK:
				if preview_texture == null:
					preview_texture = ImageTexture.create_from_image(img)
				else:
					preview_texture.update(img)
		
		_process_gestures()
		emit_signal("hand_data_updated", data)

func _process_gestures():
	var now = Time.get_ticks_msec() / 1000.0
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var cooldown = s_mgr.gesture_cooldown if s_mgr else 0.8
	var grab_setting = s_mgr.grab_gesture if s_mgr else "pinch"
	var release_setting = s_mgr.release_gesture if s_mgr else "pinch"
	
	# Grab gesture trigger (edge: false -> true)
	var grab_active = false
	if grab_setting == "pinch":
		grab_active = is_pinching
	elif grab_setting == "palm":
		grab_active = is_open_palm
		
	var release_active = false
	if release_setting == "pinch":
		release_active = is_pinching
	elif release_setting == "palm":
		release_active = is_open_palm

	# Check grab trigger on transition
	if grab_active and not prev_pinch_state:
		if now - last_gesture_time >= cooldown:
			last_gesture_time = now
			emit_signal("grab_gesture_triggered")
			
	# Check release trigger on transition
	if release_active and not prev_palm_state:
		if now - last_gesture_time >= cooldown:
			last_gesture_time = now
			emit_signal("release_gesture_triggered")

	prev_pinch_state = is_pinching
	prev_palm_state = is_open_palm

func calibrate_neutral():
	neutral_x = hand_x
	neutral_y = hand_y

func get_mapped_claw_position(min_x: float, max_x: float, min_z: float, max_z: float) -> Vector2:
	if not hand_detected:
		return Vector2.ZERO
		
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var h_sens = s_mgr.horizontal_sensitivity if s_mgr else 1.2
	var d_sens = s_mgr.depth_sensitivity if s_mgr else 1.2
	var inv_h = s_mgr.invert_horizontal if s_mgr else false
	
	# Active range mapping with comfortable center window
	var x_span = clamp(0.55 / clamp(h_sens, 0.5, 3.0), 0.15, 0.90)
	var x_min = 0.50 - x_span * 0.50
	var x_max = 0.50 + x_span * 0.50
	var norm_x = clamp((hand_x - x_min) / (x_max - x_min), 0.0, 1.0)
	if inv_h:
		norm_x = 1.0 - norm_x
		
	# Low Y (top of webcam frame / hand forward) -> min_z (back wall)
	# High Y (bottom of webcam frame / hand backward) -> max_z (front glass)
	var y_span = clamp(0.55 / clamp(d_sens, 0.5, 3.0), 0.15, 0.90)
	var y_min = 0.50 - y_span * 0.50
	var y_max = 0.50 + y_span * 0.50
	var norm_z = clamp((hand_y - y_min) / (y_max - y_min), 0.0, 1.0)
	
	var target_x = lerp(min_x, max_x, norm_x)
	var target_z = lerp(min_z, max_z, norm_z)
	return Vector2(target_x, target_z)

func get_control_vector() -> Vector2:
	# Returns (X: left/right, Y: forward/backward) normalized [-1.0 .. 1.0]
	if not hand_detected:
		return Vector2.ZERO
		
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var h_sens = s_mgr.horizontal_sensitivity if s_mgr else 1.3
	var d_sens = s_mgr.depth_sensitivity if s_mgr else 1.3
	var inv_h = s_mgr.invert_horizontal if s_mgr else false
	var deadzone = s_mgr.dead_zone if s_mgr else 0.03
	
	# Compute displacement from neutral reference
	# Multiply by responsive gain curve
	var dx = (hand_x - neutral_x) * 2.5 * h_sens
	var dy = (hand_y - neutral_y) * 2.5 * d_sens
	
	if inv_h:
		dx = -dx
		
	if abs(dx) < deadzone:
		dx = 0.0
	else:
		dx = sign(dx) * ((abs(dx) - deadzone) / (1.0 - deadzone))
		
	if abs(dy) < deadzone:
		dy = 0.0
	else:
		dy = sign(dy) * ((abs(dy) - deadzone) / (1.0 - deadzone))
		
	return Vector2(clamp(dx, -1.0, 1.0), clamp(dy, -1.0, 1.0))
