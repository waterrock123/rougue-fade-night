class_name CharacterSelector
extends Control

const RUN_SCENE := preload("res://scenes/run/run.tscn")
const SCOUNT_STATS := preload("res://character_resource/scount/scount.tres")
const WARRIOR_STATS := preload("res://character_resource/warrior/warrior.tres")
const WIZARD_STATS := preload("res://character_resource/wizard/wizard.tres")

@export var run_startup: RunStartup

@onready var title: Label = %Title
@onready var description: Label = %Desc
@onready var character_portrait: TextureRect = %BackGround

var current_character: Character : set = set_current_character


# 进入角色选择时，先给一个默认角色，避免未选择就开始时拿不到数据。
func _ready() -> void:
	if current_character == null:
		set_current_character(WARRIOR_STATS)


# 切换当前角色时，同时刷新展示信息。
func set_current_character(new_character: Character) -> void:
	current_character = new_character
	if current_character == null:
		return

	title.text = current_character.character_name
	description.text = current_character.description
	character_portrait.texture = current_character.background


func _on_warrior_button_pressed() -> void:
	set_current_character(WARRIOR_STATS)


func _on_scount_button_pressed() -> void:
	set_current_character(SCOUNT_STATS)


func _on_wizard_button_pressed() -> void:
	set_current_character(WIZARD_STATS)


# 点击开始后构建一份 RunStartup，并把它交给 Run 场景初始化本局数据。
func _on_start_button_pressed() -> void:
	if current_character == null:
		return

	if run_startup == null:
		run_startup = RunStartup.new()

	run_startup.type = RunStartup.Type.NEW_RUN
	run_startup.picked_character = current_character
	Run.pending_startup = run_startup
	get_tree().change_scene_to_packed(RUN_SCENE)
