class_name DeathScreen
extends Control

const CHARACTER_SELECTOR_SCENE := preload("res://scenes/character_selector.tscn")
const HOME_SCENE := preload("res://scenes/home_scene.tscn")

@onready var restart_button: Button = %RestartButton
@onready var home_button: Button = %HomeButton


func _ready() -> void:
	get_tree().paused = false
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)
	if home_button != null and not home_button.pressed.is_connected(_on_home_button_pressed):
		home_button.pressed.connect(_on_home_button_pressed)


# 重新开始一局时回到角色选择界面，让玩家重新选择角色。
func _on_restart_button_pressed() -> void:
	Run.pending_startup = null
	get_tree().change_scene_to_packed(CHARACTER_SELECTOR_SCENE)


# 退出本局，返回主界面。
func _on_home_button_pressed() -> void:
	Run.pending_startup = null
	get_tree().change_scene_to_packed(HOME_SCENE)
