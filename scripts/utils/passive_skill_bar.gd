class_name PassiveSkillBar
extends PanelContainer

@export var button_container: Node

var passive_skill_uis: Array[PassiveSkillUI] = []


func _ready() -> void:
	_collect_slots()


# 根据玩家构筑刷新战斗场景里的被动技能展示栏。
func refresh_from_player_build(player_build: PlayerBuild) -> void:
	if passive_skill_uis.is_empty():
		_collect_slots()

	var entries: Array[SkillEntry] = []
	if player_build != null:
		entries = player_build.owned_passive_skills

	for index in range(passive_skill_uis.size()):
		var entry := entries[index] if index < entries.size() else null
		passive_skill_uis[index].setup(entry)


# 收集场景里预先摆好的 PassiveSkillUI 格子。
func _collect_slots() -> void:
	passive_skill_uis.clear()
	var root := button_container if button_container != null else self
	_collect_slots_recursive(root)


func _collect_slots_recursive(root: Node) -> void:
	for child in root.get_children():
		if child is PassiveSkillUI:
			passive_skill_uis.append(child)
		else:
			_collect_slots_recursive(child)
