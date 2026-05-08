class_name PassiveSkillUI
extends Control

var skill_entry: SkillEntry

@onready var icon_texture: TextureRect = %SkillTextureRect


func _ready() -> void:
	# 子节点只负责显示，不抢根节点的 tooltip 鼠标事件。
	_set_child_mouse_filter_ignore(self)


# 刷新一个被动技能格子；没有技能时显示为空格状态。
func setup(new_skill_entry: SkillEntry) -> void:
	skill_entry = new_skill_entry
	_ensure_node_refs()
	if icon_texture == null:
		return

	if skill_entry == null or skill_entry.skill_data == null:
		icon_texture.texture = null
		tooltip_text = ""
		modulate.a = 0.25
		return

	icon_texture.texture = skill_entry.skill_data.icon
	tooltip_text = " "
	modulate.a = 1.0


func _make_custom_tooltip(_for_text: String) -> Object:
	if skill_entry == null or skill_entry.skill_data == null:
		return null

	var tooltip := FloatText.SKILL_TOOL_TIP_PANEL.instantiate() as SkillToolTipPanel
	tooltip.set_skill(skill_entry)
	return tooltip


func _set_child_mouse_filter_ignore(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_child_mouse_filter_ignore(child)


func _ensure_node_refs() -> void:
	if icon_texture == null:
		icon_texture = get_node_or_null("MarginContainer/SkillTextureRect") as TextureRect
