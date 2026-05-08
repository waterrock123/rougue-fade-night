class_name SpellUI
extends Control

var skill_entry: SkillEntry

@onready var icon_texture: TextureRect = $TextureRect


func _ready() -> void:
	# 技能格子的子节点只负责绘制，让根节点接管 tooltip 触发。
	_set_child_mouse_filter_ignore(self)


# 显示一个已拥有技能；空技能会把格子清空。
func setup(new_skill_entry: SkillEntry) -> void:
	skill_entry = new_skill_entry
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
