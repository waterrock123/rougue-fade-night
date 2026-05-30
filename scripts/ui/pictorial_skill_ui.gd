class_name PictorialSkillUI
extends CenterContainer

signal selected(ui: PictorialSkillUI, skill_data: SkillData)

var skill_data: SkillData

@onready var button: Button = $Button
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %Namelabel
@onready var character_label: Label = %CharacterLabel


func _ready() -> void:
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


# 主动和被动技能的图鉴格子结构一致，所以共用这份脚本。
func setup(new_skill_data: SkillData) -> void:
	skill_data = new_skill_data
	_resolve_nodes()
	if skill_data == null:
		hide()
		return

	show()
	if icon_rect != null:
		icon_rect.texture = skill_data.icon
	if name_label != null:
		name_label.text = skill_data.skill_name
	if character_label != null:
		character_label.text = _get_character_text(skill_data)


func set_selected(value: bool) -> void:
	_resolve_nodes()
	if button != null:
		button.button_pressed = value


func _on_button_pressed() -> void:
	selected.emit(self, skill_data)


func _get_character_text(data: SkillData) -> String:
	if data.allowed_character_ids.is_empty():
		return "通用"

	var names: Array[String] = []
	for character_id in data.allowed_character_ids:
		names.append(_get_character_display_name(character_id))
	return "、".join(names)


func _get_character_display_name(character_id: StringName) -> String:
	match character_id:
		&"warrior":
			return "战狂"
		&"scount":
			return "浪子"
		&"wizard":
			return "贵人"
		_:
			return String(character_id)


func _resolve_nodes() -> void:
	if button == null:
		button = get_node_or_null("Button") as Button
	if icon_rect == null:
		icon_rect = get_node_or_null("%Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("%Namelabel") as Label
	if character_label == null:
		character_label = get_node_or_null("%CharacterLabel") as Label
