extends Node

# Persistent Settings Manager using ConfigFile
const SETTINGS_FILE = "user://settings.cfg"

# Hand Tracking Settings
var hand_sensitivity: float = 1.3
var horizontal_sensitivity: float = 1.3
var depth_sensitivity: float = 1.3
var movement_smoothing: float = 0.35
var dead_zone: float = 0.03
var max_claw_speed: float = 0.60
var invert_horizontal: bool = false
var grab_gesture: String = "pinch" # "pinch" or "palm"
var release_gesture: String = "pinch" # "pinch" or "palm"
var gesture_threshold: float = 0.45
var gesture_cooldown: float = 0.65
var webcam_preview_enabled: bool = true
var keyboard_fallback_enabled: bool = true

# Graphics Settings
var graphics_quality: String = "High" # "Low", "Medium", "High"
var fullscreen: bool = false
var vsync: bool = true
var shadow_quality: String = "High"
var camera_fov: float = 62.0

# Camera Settings
var camera_orbit_sensitivity: float = 0.005
var camera_invert_x: bool = false
var camera_invert_y: bool = false
var camera_min_dist: float = 1.2
var camera_max_dist: float = 3.5
var camera_smoothing: float = 8.0

# Audio Settings
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var mute_audio: bool = false

# Gameplay Settings
var default_round_duration: int = 60 # 30 or 60
var grab_difficulty: float = 0.95 # generous success rate for fun playability
var show_tutorial: bool = true
var show_hand_indicators: bool = true
var show_control_hints: bool = true

# High Scores & Collection
var high_score_30: int = 0
var high_score_60: int = 0
var collected_toys: Dictionary = {}

signal settings_changed
signal round_duration_changed(duration: int)

func _ready():
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		return
	
	hand_sensitivity = config.get_value("hand", "hand_sensitivity", hand_sensitivity)
	horizontal_sensitivity = config.get_value("hand", "horizontal_sensitivity", horizontal_sensitivity)
	depth_sensitivity = config.get_value("hand", "depth_sensitivity", depth_sensitivity)
	movement_smoothing = config.get_value("hand", "movement_smoothing", movement_smoothing)
	dead_zone = config.get_value("hand", "dead_zone", dead_zone)
	max_claw_speed = config.get_value("hand", "max_claw_speed", max_claw_speed)
	invert_horizontal = config.get_value("hand", "invert_horizontal", invert_horizontal)
	grab_gesture = config.get_value("hand", "grab_gesture", grab_gesture)
	release_gesture = config.get_value("hand", "release_gesture", release_gesture)
	gesture_threshold = config.get_value("hand", "gesture_threshold", gesture_threshold)
	gesture_cooldown = config.get_value("hand", "gesture_cooldown", gesture_cooldown)
	
	graphics_quality = config.get_value("graphics", "graphics_quality", graphics_quality)
	fullscreen = config.get_value("graphics", "fullscreen", fullscreen)
	vsync = config.get_value("graphics", "vsync", vsync)
	camera_fov = config.get_value("graphics", "camera_fov", camera_fov)
	
	camera_orbit_sensitivity = config.get_value("camera", "orbit_sensitivity", camera_orbit_sensitivity)
	camera_invert_x = config.get_value("camera", "invert_x", camera_invert_x)
	camera_invert_y = config.get_value("camera", "invert_y", camera_invert_y)
	
	master_volume = config.get_value("audio", "master_volume", master_volume)
	music_volume = config.get_value("audio", "music_volume", music_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	mute_audio = config.get_value("audio", "mute_audio", mute_audio)
	
	default_round_duration = config.get_value("gameplay", "default_round_duration", default_round_duration)
	grab_difficulty = config.get_value("gameplay", "grab_difficulty", grab_difficulty)
	show_tutorial = config.get_value("gameplay", "show_tutorial", show_tutorial)
	show_hand_indicators = config.get_value("gameplay", "show_hand_indicators", show_hand_indicators)
	
	high_score_30 = config.get_value("scores", "high_score_30", 0)
	high_score_60 = config.get_value("scores", "high_score_60", 0)
	collected_toys = config.get_value("scores", "collected_toys", {})
	
	apply_settings()

func save_settings():
	var config = ConfigFile.new()
	
	config.set_value("hand", "hand_sensitivity", hand_sensitivity)
	config.set_value("hand", "horizontal_sensitivity", horizontal_sensitivity)
	config.set_value("hand", "depth_sensitivity", depth_sensitivity)
	config.set_value("hand", "movement_smoothing", movement_smoothing)
	config.set_value("hand", "dead_zone", dead_zone)
	config.set_value("hand", "max_claw_speed", max_claw_speed)
	config.set_value("hand", "invert_horizontal", invert_horizontal)
	config.set_value("hand", "grab_gesture", grab_gesture)
	config.set_value("hand", "release_gesture", release_gesture)
	config.set_value("hand", "gesture_threshold", gesture_threshold)
	config.set_value("hand", "gesture_cooldown", gesture_cooldown)
	
	config.set_value("graphics", "graphics_quality", graphics_quality)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "camera_fov", camera_fov)
	
	config.set_value("camera", "orbit_sensitivity", camera_orbit_sensitivity)
	config.set_value("camera", "invert_x", camera_invert_x)
	config.set_value("camera", "invert_y", camera_invert_y)
	
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "mute_audio", mute_audio)
	
	config.set_value("gameplay", "default_round_duration", default_round_duration)
	config.set_value("gameplay", "grab_difficulty", grab_difficulty)
	config.set_value("gameplay", "show_tutorial", show_tutorial)
	config.set_value("gameplay", "show_hand_indicators", show_hand_indicators)
	
	config.set_value("scores", "high_score_30", high_score_30)
	config.set_value("scores", "high_score_60", high_score_60)
	config.set_value("scores", "collected_toys", collected_toys)
	
	config.save(SETTINGS_FILE)
	apply_settings()

func apply_settings():
	# Window mode
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	# VSync
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
	# Audio busses
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, mute_audio)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
		
	emit_signal("settings_changed")

func record_high_score(duration: int, score: int) -> bool:
	var new_record = false
	if duration == 30:
		if score > high_score_30:
			high_score_30 = score
			new_record = true
	elif duration == 60:
		if score > high_score_60:
			high_score_60 = score
			new_record = true
	if new_record:
		save_settings()
	return new_record

func record_toy_collected(toy_id: String):
	if not collected_toys.has(toy_id):
		collected_toys[toy_id] = 0
	collected_toys[toy_id] += 1
	save_settings()

