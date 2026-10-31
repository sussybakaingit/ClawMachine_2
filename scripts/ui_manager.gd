class_name UIManager
extends CanvasLayer

@onready var hud_panel: Control = $HUD
@onready var lbl_time: Label = $HUD/TopBar/Margin/HBox/TimePanel/LblTime
@onready var lbl_score: Label = $HUD/TopBar/Margin/HBox/ScorePanel/LblScore
@onready var lbl_delivered: Label = $HUD/TopBar/Margin/HBox/DeliveredPanel/LblDelivered
@onready var lbl_claw_state: Label = $HUD/ClawStatePanel/LblClawState

# Hand Tracker HUD widget
@onready var ht_status_panel: PanelContainer = $HUD/HandTrackingHUD
@onready var lbl_ht_status: Label = $HUD/HandTrackingHUD/VBox/LblStatus
@onready var lbl_ht_confidence: Label = $HUD/HandTrackingHUD/VBox/LblConfidence
@onready var lbl_ht_gesture: Label = $HUD/HandTrackingHUD/VBox/LblGesture
@onready var hand_cursor: Control = $HUD/HandTrackingHUD/VBox/Visualizer/Cursor
@onready var hand_preview_rect: TextureRect = $HUD/HandTrackingHUD/VBox/Visualizer/PreviewRect

# Delivery celebration banner
@onready var celebration_banner: PanelContainer = $HUD/CelebrationBanner
@onready var lbl_celebration_msg: Label = $HUD/CelebrationBanner/LblMessage

# Sub-menus
@onready var pause_menu: Control = $PauseMenu
@onready var results_screen: Control = $ResultsScreen
@onready var tutorial_dialog: Control = $TutorialDialog
@onready var settings_menu: Control = $SettingsMenu

# Results labels
@onready var lbl_final_score: Label = $ResultsScreen/Panel/VBox/LblFinalScore
@onready var lbl_final_toys: Label = $ResultsScreen/Panel/VBox/LblFinalToys
@onready var lbl_record_badge: Label = $ResultsScreen/Panel/VBox/LblRecordBadge

var game_manager: Node
var camera_controller: Node

func setup(gm: Node, cam: Node):
	game_manager = gm
	camera_controller = cam
	
	if not is_node_ready():
		await ready
	
	game_manager.score_changed.connect(_on_score_changed)
	game_manager.timer_updated.connect(_on_timer_updated)
	game_manager.prize_delivered.connect(_on_prize_delivered)
	game_manager.game_over.connect(_on_game_over)
	
	if game_manager.claw_controller:
		game_manager.claw_controller.state_changed.connect(_on_claw_state_changed)
		
	var ht = get_node_or_null("/root/HandTrackingClient")
	if ht:
		ht.hand_data_updated.connect(_on_hand_data_updated)
		
	if celebration_banner: celebration_banner.visible = false
	if pause_menu: pause_menu.visible = false
	if results_screen: results_screen.visible = false
	if settings_menu: settings_menu.visible = false
	
	var s_mgr = get_node_or_null("/root/SettingsManager")
	if tutorial_dialog:
		if s_mgr and s_mgr.show_tutorial:
			tutorial_dialog.visible = true
		else:
			tutorial_dialog.visible = false

func _on_score_changed(score: int, combo: int):
	if lbl_score:
		lbl_score.text = "SCORE: %d (x%d)" % [score, combo]

func _on_timer_updated(time_left: float):
	if lbl_time:
		lbl_time.text = "TIME: %02d" % int(ceil(time_left))
		if time_left <= 10.0 and time_left > 0.0:
			lbl_time.modulate = Color.RED
		else:
			lbl_time.modulate = Color.WHITE

func _on_claw_state_changed(new_state: int):
	if not lbl_claw_state:
		return
	var s_name = "IDLE"
	match new_state:
		0: s_name = "READY"
		1: s_name = "MOVING"
		2: s_name = "DESCENDING..."
		3: s_name = "GRABBING..."
		4: s_name = "LIFTING..."
		5: s_name = "CARRYING (MANUAL CONTROL)"
		6: s_name = "DELIVERING..."
		7: s_name = "RELEASING..."
	lbl_claw_state.text = "CLAW: " + s_name

func _on_prize_delivered(toy_name: String, points: int):
	lbl_delivered.text = "DELIVERED: %d" % game_manager.toys_delivered_count
	lbl_celebration_msg.text = "🎉 DELIVERED: %s (+%d pts)!" % [toy_name, points]
	celebration_banner.visible = true
	celebration_banner.scale = Vector2(0.5, 0.5)
	
	var tw = create_tween()
	tw.tween_property(celebration_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(celebration_banner, "scale", Vector2(0.1, 0.1), 0.2)
	tw.tween_callback(func(): celebration_banner.visible = false)

func _on_hand_data_updated(data: Dictionary):
	var detected = data.get("hand_detected", false)
	var cam_active = data.get("camera_active", false)
	
	if not cam_active:
		lbl_ht_status.text = "CAM: Disconnected (Using Keyboard)"
		lbl_ht_status.modulate = Color.ORANGE
	elif detected:
		lbl_ht_status.text = "HAND: Active"
		lbl_ht_status.modulate = Color.GREEN
	else:
		lbl_ht_status.text = "HAND: Looking for hand..."
		lbl_ht_status.modulate = Color.YELLOW
		
	var conf = data.get("confidence", 0.0) * 100.0
	lbl_ht_confidence.text = "Confidence: %d%%" % int(conf)
	
	var gesture_str = "None"
	if data.get("pinching", false):
		gesture_str = "PINCH (Grab/Release)"
	elif data.get("open_palm", false):
		gesture_str = "OPEN PALM"
	lbl_ht_gesture.text = "Gesture: " + gesture_str
	
	# Update visual preview texture from webcam hand landmarks if available
	var ht = get_node_or_null("/root/HandTrackingClient")
	if hand_preview_rect and ht and ht.preview_texture:
		hand_preview_rect.texture = ht.preview_texture
	
	# Update visual cursor in 2D minimap box
	if hand_cursor:
		var x = data.get("x", 0.5)
		var y = data.get("y", 0.5)
		hand_cursor.position = Vector2(x * 190.0, y * 130.0)

func _on_game_over(final_score: int, toys_count: int, is_new_record: bool):
	results_screen.visible = true
	lbl_final_score.text = "Final Score: %d" % final_score
	lbl_final_toys.text = "Toys Delivered: %d" % toys_count
	lbl_record_badge.visible = is_new_record

# HUD Button Callbacks
func _on_btn_pause_pressed():
	pause_menu.visible = true
	get_tree().paused = true

func _on_btn_resume_pressed():
	pause_menu.visible = false
	get_tree().paused = false

func _on_btn_restart_pressed():
	pause_menu.visible = false
	results_screen.visible = false
	get_tree().paused = false
	game_manager.start_game(game_manager.selected_duration)

func _on_btn_settings_pressed():
	settings_menu.visible = true

func _on_btn_close_settings_pressed():
	settings_menu.visible = false

func _on_btn_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_btn_cam_front_pressed():
	if camera_controller: camera_controller.set_preset("front")

func _on_btn_cam_side_pressed():
	if camera_controller: camera_controller.set_preset("side")

func _on_btn_cam_top_pressed():
	if camera_controller: camera_controller.set_preset("top")

func _on_btn_cam_hole_pressed():
	if camera_controller: camera_controller.set_preset("hole")

func _on_btn_cam_reset_pressed():
	if camera_controller: camera_controller.set_preset("reset")

func _on_btn_close_tutorial_pressed():
	tutorial_dialog.visible = false
