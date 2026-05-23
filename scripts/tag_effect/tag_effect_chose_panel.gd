class_name TagEffectChosePanel
extends Control

signal closed

const TAG_BUTTON_SCENE := preload("res://scenes/tag_effect_show_button.tscn")
const EFFECT_DETAIL_SCENE := preload("res://scenes/effect_detail_ui.tscn")

@export var database: TagEffectDatabase = preload("res://custom_resource/default_tag_effect_database.tres")

@onready var tag_button_container: VBoxContainer = $CenterContainer/TagList/ScrollContainer/VBoxContainer
@onready var effect_detail_container: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer
@onready var exit_button: Button = $ExitButton

var tag_buttons: Array[TagEffectShowButton] = []
var detail_items: Array[TagEffectDetailUI] = []
var current_tag: RelicTag


func _ready() -> void:
	if database != null:
		database.load_selection()

	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)

	_build_tag_buttons()
	_select_first_tag()


func _build_tag_buttons() -> void:
	_resolve_nodes()
	_clear_tag_buttons()
	if database == null or tag_button_container == null:
		return

	for tag in database.get_all_tags():
		var button := TAG_BUTTON_SCENE.instantiate() as TagEffectShowButton
		tag_button_container.add_child(button)
		button.setup(tag, database.get_selected_effect_for_tag(tag))
		button.tag_pressed.connect(_on_tag_button_pressed)
		tag_buttons.append(button)


func _select_first_tag() -> void:
	if tag_buttons.is_empty():
		_refresh_effect_details(null)
		return

	_on_tag_button_pressed(tag_buttons[0].tag)


func _on_tag_button_pressed(tag: RelicTag) -> void:
	current_tag = tag
	for button in tag_buttons:
		button.set_selected(button.tag == tag)

	_refresh_effect_details(tag)


func _refresh_effect_details(tag: RelicTag) -> void:
	_resolve_nodes()
	_clear_effect_details()
	if database == null or effect_detail_container == null or tag == null:
		return

	var selected_effect := database.get_selected_effect_for_tag(tag)
	for effect in database.get_effects_for_tag(tag):
		var detail := EFFECT_DETAIL_SCENE.instantiate() as TagEffectDetailUI
		effect_detail_container.add_child(detail)
		detail.setup(effect, effect == selected_effect)
		detail.choose_requested.connect(_on_effect_choose_requested)
		detail_items.append(detail)


func _on_effect_choose_requested(effect: TagEffect) -> void:
	if database == null or effect == null:
		return

	database.select_effect(effect)
	_update_current_tag_buttons(effect.tag)
	_refresh_effect_details(effect.tag)


func _update_current_tag_buttons(tag: RelicTag) -> void:
	for button in tag_buttons:
		if button.tag != tag:
			continue

		button.setup(tag, database.get_selected_effect_for_tag(tag))
		button.set_selected(true)


func _on_exit_button_pressed() -> void:
	closed.emit()
	queue_free()


func _clear_tag_buttons() -> void:
	for child in tag_button_container.get_children():
		child.queue_free()
	tag_buttons.clear()


func _clear_effect_details() -> void:
	for child in effect_detail_container.get_children():
		child.queue_free()
	detail_items.clear()


func _resolve_nodes() -> void:
	if tag_button_container == null:
		tag_button_container = get_node_or_null("CenterContainer/TagList/ScrollContainer/VBoxContainer") as VBoxContainer
	if effect_detail_container == null:
		effect_detail_container = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer") as VBoxContainer
	if exit_button == null:
		exit_button = get_node_or_null("ExitButton") as Button
