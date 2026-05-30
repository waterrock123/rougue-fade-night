class_name PictorialSkillBookDetail
extends VBoxContainer

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var character_label: Label = %CharacterLabel
@onready var tooltip_label: Label = %TooltipLabel
@onready var mana_cost_label: Label = get_node_or_null("%ManaCostLabel") as Label
@onready var cooldown_label: Label = get_node_or_null("%TimeFreshLabel") as Label


# 主动/被动技能详情共用脚本；主动技能存在蓝耗和冷却字段，被动技能则隐藏这些信息。
func setup(skill_data: SkillData) -> void:
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
	if tooltip_label != null:
		tooltip_label.text = KeywordTextFormatter.format_text_plain(skill_data.desc, keyword_database)

	_refresh_active_skill_values(skill_data)


func _refresh_active_skill_values(skill_data: SkillData) -> void:
	var active_data := skill_data as ActiveSkillData
	var has_active_values := active_data != null

	if mana_cost_label != null:
		mana_cost_label.text = str(active_data.base_energy_cost if has_active_values else 0)
		_set_branch_visible(mana_cost_label, has_active_values)
	if cooldown_label != null:
		cooldown_label.text = str(active_data.base_cooldown if has_active_values else 0)
		_set_branch_visible(cooldown_label, has_active_values)


func _set_branch_visible(node: Node, value: bool) -> void:
	var current := node
	while current != null and current != self:
		if current is HBoxContainer:
			(current as HBoxContainer).visible = value
			return
		current = current.get_parent()


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
	if icon_rect == null:
		icon_rect = get_node_or_null("%Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("%NameLabel") as Label
	if character_label == null:
		character_label = get_node_or_null("%CharacterLabel") as Label
	if tooltip_label == null:
		tooltip_label = get_node_or_null("%TooltipLabel") as Label
	if mana_cost_label == null:
		mana_cost_label = get_node_or_null("%ManaCostLabel") as Label
	if cooldown_label == null:
		cooldown_label = get_node_or_null("%TimeFreshLabel") as Label
