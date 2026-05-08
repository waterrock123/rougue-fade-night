class_name SkillOverviewPanel
extends PanelContainer

const SKILL_SLOT_SCENE := preload("res://scenes/ui/passive_skill_ui.tscn")

@export var empty_active_slot_count: int = 4
@export var empty_passive_slot_count: int = 4

@onready var active_container: HBoxContainer = %ActiveSkillContainer
@onready var passive_container: HBoxContainer = %PassiveSkillContainer

var player_build: PlayerBuild


func _ready() -> void:
	refresh()
	close_panel()


# 绑定本局玩家构筑，之后面板只从 PlayerBuild 读取技能展示数据。
func setup(new_player_build: PlayerBuild) -> void:
	player_build = new_player_build
	refresh()


# 刷新主动技能和被动技能图标。
func refresh() -> void:
	if not is_inside_tree():
		return

	_refresh_skill_group(active_container, _get_active_entries(), empty_active_slot_count)
	_refresh_skill_group(passive_container, _get_passive_entries(), empty_passive_slot_count)


func open_panel() -> void:
	refresh()
	show()


func close_panel() -> void:
	hide()


# 根据技能数量动态重建格子，避免手动在场景里维护很多重复节点。
func _refresh_skill_group(container: HBoxContainer, entries: Array[SkillEntry], minimum_slots: int) -> void:
	if container == null:
		return

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	var slot_count = max(minimum_slots, entries.size())
	for index in range(slot_count):
		var slot_ui := SKILL_SLOT_SCENE.instantiate() as PassiveSkillUI
		container.add_child(slot_ui)
		var entry := entries[index] if index < entries.size() else null
		slot_ui.setup(entry)


func _get_active_entries() -> Array[SkillEntry]:
	if player_build == null:
		return []
	return player_build.owned_active_skills


func _get_passive_entries() -> Array[SkillEntry]:
	if player_build == null:
		return []
	return player_build.owned_passive_skills
