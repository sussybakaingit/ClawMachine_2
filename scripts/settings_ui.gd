class_name SettingsUI
extends Control

# Hand Sliders
@onready var slider_hand_sens: HSlider = $Panel/MainVBox/TabContainer/Controls/VBox/HandSens/Slider
@onready var slider_smoothing: HSlider = $Panel/MainVBox/TabContainer/Controls/VBox/Smoothing/Slider
@onready var slider_deadzone: HSlider = $Panel/MainVBox/TabContainer/Controls/VBox/Deadzone/Slider
@onready var chk_invert_h: CheckBox = $Panel/MainVBox/TabContainer/Controls/VBox/InvertH
@onready var opt_grab_gesture: OptionButton = $Panel/MainVBox/TabContainer/Controls/VBox/GrabGesture/Option
@onready var opt_release_gesture: OptionButton = $Panel/MainVBox/TabContainer/Controls/VBox/ReleaseGesture/Option

# Graphics Controls
@onready var opt_quality: OptionButton = $Panel/MainVBox/TabContainer/Graphics/VBox/Quality/Option
@onready var chk_fullscreen: CheckBox = $Panel/MainVBox/TabContainer/Graphics/VBox/Fullscreen
@onready var chk_vsync: CheckBox = $Panel/MainVBox/TabContainer/Graphics/VBox/VSync
@onready var slider_fov: HSlider = $Panel/MainVBox/TabContainer/Graphics/VBox/FOV/Slider

# Audio Sliders
@onready var slider_master: HSlider = $Panel/MainVBox/TabContainer/Audio/VBox/MasterVol/Slider
@onready var slider_music: HSlider = $Panel/MainVBox/TabContainer/Audio/VBox/MusicVol/Slider
@onready var slider_sfx: HSlider = $Panel/MainVBox/TabContainer/Audio/VBox/SFXVol/Slider
@onready var chk_mute: CheckBox = $Panel/MainVBox/TabContainer/Audio/VBox/Mute

# Gameplay
@onready var opt_duration: OptionButton = $Panel/MainVBox/TabContainer/Gameplay/VBox/Duration/Option
@onready var slider_grip: HSlider = $Panel/MainVBox/TabContainer/Gameplay/VBox/GripDiff/Slider
@onready var chk_tutorial: CheckBox = $Panel/MainVBox/TabContainer/Gameplay/VBox/ShowTutorial

func _ready():
	_populate_options()
	_load_values_to_ui()

func _populate_options():
	opt_grab_gesture.clear()
	opt_grab_gesture.add_item("Pinch Gesture", 0)
	opt_grab_gesture.add_item("Open Palm Gesture", 1)
	
	opt_release_gesture.clear()
	opt_release_gesture.add_item("Pinch Gesture", 0)
	opt_release_gesture.add_item("Open Palm Gesture", 1)
	
	opt_quality.clear()
	opt_quality.add_item("Low", 0)
	opt_quality.add_item("Medium", 1)
	opt_quality.add_item("High", 2)
	
	opt_duration.clear()
	opt_duration.add_item("60 Seconds", 0)
	opt_duration.add_item("30 Seconds", 1)

func _load_values_to_ui():
	var s = get_node_or_null("/root/SettingsManager")
	if not s: return
	
	slider_hand_sens.value = s.hand_sensitivity
	slider_smoothing.value = s.movement_smoothing
	slider_deadzone.value = s.dead_zone
	chk_invert_h.button_pressed = s.invert_horizontal
	opt_grab_gesture.selected = 0 if s.grab_gesture == "pinch" else 1
	opt_release_gesture.selected = 0 if s.release_gesture == "pinch" else 1
	
	chk_fullscreen.button_pressed = s.fullscreen
	chk_vsync.button_pressed = s.vsync
	slider_fov.value = s.camera_fov
	
	slider_master.value = s.master_volume
	slider_music.value = s.music_volume
	slider_sfx.value = s.sfx_volume
	chk_mute.button_pressed = s.mute_audio
	
	opt_duration.selected = 0 if s.default_round_duration == 60 else 1
	slider_grip.value = s.grab_difficulty
	chk_tutorial.button_pressed = s.show_tutorial

func save_and_apply():
	var s = get_node_or_null("/root/SettingsManager")
	if not s: return
	
	s.hand_sensitivity = slider_hand_sens.value
	s.movement_smoothing = slider_smoothing.value
	s.dead_zone = slider_deadzone.value
	s.invert_horizontal = chk_invert_h.button_pressed
	s.grab_gesture = "pinch" if opt_grab_gesture.selected == 0 else "palm"
	s.release_gesture = "pinch" if opt_release_gesture.selected == 0 else "palm"
	
	s.fullscreen = chk_fullscreen.button_pressed
	s.vsync = chk_vsync.button_pressed
	s.camera_fov = slider_fov.value
	
	s.master_volume = slider_master.value
	s.music_volume = slider_music.value
	s.sfx_volume = slider_sfx.value
	s.mute_audio = chk_mute.button_pressed
	
	s.default_round_duration = 60 if opt_duration.selected == 0 else 30
	s.grab_difficulty = slider_grip.value
	s.show_tutorial = chk_tutorial.button_pressed
	
	s.save_settings()

func _on_btn_recalibrate_pressed():
	var ht = get_node_or_null("/root/HandTrackingClient")
	if ht:
		ht.calibrate_neutral()

func _on_btn_close_pressed():
	save_and_apply()
	visible = false
