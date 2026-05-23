class_name TagEffectDetailUI
extends VBoxContainer

signal choose_requested(effect: TagEffect)

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

@onready var icon_rect: TextureRect = $VBoxContainer2/EffectName/HBoxContainer/icon
@onready var name_label: Label = $VBoxContainer2/EffectName/HBoxContainer/Name
@onready var desc_label: RichTextLabel = $VBoxContainer2/DetailDesc
@onready var chosen_button: Button = $VBoxContainer2/DetailDesc/ChosenButton

var effect: TagEffect


func _ready() -> void:
	if chosen_button != null and not chosen_button.pressed.is_connected(_on_chosen_button_pressed):
		chosen_button.pressed.connect(_on_chosen_button_pressed)


func setup(new_effect: TagEffect, is_selected: bool) -> void:
	_resolve_nodes()
	effect = new_effect

	if icon_rect != null:
		icon_rect.texture = effect.icon if effect != null else null
		icon_rect.visible = icon_rect.texture != null

	if name_label != null:
		name_label.text = effect.get_display_name() if effect != null else ""

	if desc_label != null:
		desc_label.bbcode_enabled = true
		var raw_desc := effect.desc if effect != null else ""
		var result := KeywordTextFormatter.format_text(raw_desc, keyword_database)
		desc_label.text = result.bbcode_text

	set_selected(is_selected)
	show()


func set_selected(is_selected: bool) -> void:
	_resolve_nodes()
	if chosen_button == null:
		return

	chosen_button.button_pressed = is_selected
	chosen_button.text = "已激活" if is_selected else "未激活"


func _on_chosen_button_pressed() -> void:
	if effect == null:
		return

	choose_requested.emit(effect)


func _resolve_nodes() -> void:
	if icon_rect == null:
		icon_rect = get_node_or_null("VBoxContainer2/EffectName/HBoxContainer/icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("VBoxContainer2/EffectName/HBoxContainer/Name") as Label
	if desc_label == null:
		desc_label = get_node_or_null("VBoxContainer2/DetailDesc") as RichTextLabel
	if chosen_button == null:
		chosen_button = get_node_or_null("VBoxContainer2/DetailDesc/ChosenButton") as Button
