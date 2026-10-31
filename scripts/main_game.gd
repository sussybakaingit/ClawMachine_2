extends Node3D

@onready var claw_machine: Node3D = $ClawMachine
@onready var camera_rig: Node3D = $CameraRig
@onready var ui_manager: CanvasLayer = $UIManager

var game_manager: Node

func _ready():
	var gm_script = load("res://scripts/game_manager.gd")
	game_manager = gm_script.new()
	add_child(game_manager)
	
	var claw_controller = claw_machine.get_node_or_null("ClawAssembly")
	var prize_manager = claw_machine.get_node_or_null("PrizeManager")
	var delivery_hole = claw_machine.get_node_or_null("DeliveryHoleArea")
	
	game_manager.setup(claw_controller, prize_manager, delivery_hole, camera_rig)
	if camera_rig and camera_rig.has_method("set_claw_target"):
		camera_rig.set_claw_target(claw_controller)
	ui_manager.setup(game_manager, camera_rig)
	
	var s_mgr = get_node_or_null("/root/SettingsManager")
	var duration = s_mgr.default_round_duration if s_mgr else 60
	game_manager.start_game(duration)
