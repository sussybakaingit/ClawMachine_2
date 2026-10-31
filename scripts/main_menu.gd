class_name MainMenu
extends Control

@onready var btn_start_60: Button = $VBoxButtons/BtnStart60
@onready var btn_start_30: Button = $VBoxButtons/BtnStart30
@onready var btn_settings: Button = $VBoxButtons/BtnSettings
@onready var btn_tutorial: Button = $VBoxButtons/BtnTutorial
@onready var btn_quit: Button = $VBoxButtons/BtnQuit

@onready var lbl_high_score_60: Label = $HighScorePanel/VBox/LblScore60
@onready var lbl_high_score_30: Label = $HighScorePanel/VBox/LblScore30

@onready var settings_menu: Control = $SettingsMenu
@onready var tutorial_dialog: Control = $TutorialDialog

func _ready():
	_update_scores()
	settings_menu.visible = false
	tutorial_dialog.visible = false
	
	btn_start_60.pressed.connect(func(): _start_game(60))
	btn_start_30.pressed.connect(func(): _start_game(30))
	btn_settings.pressed.connect(func(): settings_menu.visible = true)
	btn_tutorial.pressed.connect(func(): tutorial_dialog.visible = true)
	btn_quit.pressed.connect(func(): get_tree().quit())

func _update_scores():
	var s = get_node_or_null("/root/SettingsManager")
	if s:
		lbl_high_score_60.text = "60s Best Score: %d" % s.high_score_60
		lbl_high_score_30.text = "30s Best Score: %d" % s.high_score_30

func _start_game(duration: int):
	var s = get_node_or_null("/root/SettingsManager")
	if s:
		s.default_round_duration = duration
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_close_tutorial():
	tutorial_dialog.visible = false

