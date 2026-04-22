class_name CharacterSelector
extends Control



const RUN_SCENE = preload("res://scenes/run/run.tscn")
const SCOUNT_STATS := preload("res://character_resource/scount/scount.tres")
const WARRIOR_STATS := preload("res://character_resource/warrior/warrior.tres")
const WIZARD_STATS := preload("res://character_resource/wizard/wizard.tres")


@export var run_startup: RunStartup

@onready var title: Label = %Title
@onready var description: Label = %Desc
@onready var character_portrait: TextureRect = %BackGround

var current_character: Character : set = set_current_character



func set_current_character(new_character: Character) -> void:
	current_character = new_character
	title.text = current_character.character_name
	description.text = current_character.description
	character_portrait.texture = current_character.background



func _on_warrior_button_pressed() -> void:
	current_character = WARRIOR_STATS


func _on_scount_button_pressed() -> void:
	current_character = SCOUNT_STATS


func _on_wizard_button_pressed() -> void:
	current_character = WIZARD_STATS


func _on_start_button_pressed() -> void:
	run_startup.type = RunStartup.Type.NEW_RUN
	run_startup.picked_character = current_character
	get_tree().change_scene_to_packed(RUN_SCENE)
