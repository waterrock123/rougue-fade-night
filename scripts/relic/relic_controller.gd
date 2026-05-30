class_name RelicController
extends Node

@export var equipment_inventory: Equipment
@export var player: Player
@export var player_build: PlayerBuild

var active_relic_entries: Array[Dictionary] = []
var deferred_refresh_requested := false


func _ready() -> void:
	_resolve_context()

	if not EventBus.equipment_update.is_connected(_on_equipment_changed):
		EventBus.equipment_update.connect(_on_equipment_changed)

	# 子节点 ready 时，Run/Player 可能还没把 PlayerBuild 传下来。
	# 这次延迟刷新只是兜底；如果外部已经主动 refresh_all()，它会被跳过。
	deferred_refresh_requested = true
	call_deferred("_refresh_all_deferred")


func _exit_tree() -> void:
	if EventBus.equipment_update.is_connected(_on_equipment_changed):
		EventBus.equipment_update.disconnect(_on_equipment_changed)

	# 场景销毁时也清理装备效果，避免监听全局信号的遗物效果残留到下一场景。
	_deactivate_all_relics()


# 提供给 RelicEffect 使用的统一查询入口。
func get_stats_controller() -> StatsController:
	var effect_owner := _get_effect_owner()
	if effect_owner == null:
		return null

	if effect_owner is Entity:
		return (effect_owner as Entity).stats_controller

	if effect_owner is PlayerBuildProxy:
		return (effect_owner as PlayerBuildProxy).get_stats_controller()

	return effect_owner.get_node_or_null("StatsController") as StatsController


func get_status_controller() -> StatusController:
	var effect_owner := _get_effect_owner()
	if effect_owner == null:
		return null

	if effect_owner.has_method("get_status_controller"):
		return effect_owner.get_status_controller()

	return effect_owner.get_node_or_null("StatusController") as StatusController


# 根据当前装备栏状态刷新所有遗物效果。
func refresh_all() -> void:
	deferred_refresh_requested = false
	_resolve_context()
	_deactivate_all_relics()

	if equipment_inventory == null:
		return

	var effect_owner := _get_effect_owner()
	if effect_owner == null:
		return

	for slot_index in range(equipment_inventory.equip_slots.size()):
		var slot := equipment_inventory.equip_slots[slot_index]
		if slot == null or slot.item == null:
			continue

		var relic := slot.item as Relic
		if relic == null:
			continue

		var relic_key := _build_relic_key(slot_index, relic)
		relic.activate_relic(effect_owner, self, relic_key)
		active_relic_entries.append({
			"relic": relic,
			"key": relic_key,
		})


func _on_equipment_changed() -> void:
	refresh_all()


func _refresh_all_deferred() -> void:
	if not deferred_refresh_requested:
		return

	refresh_all()


# 自动从父节点补齐引用，减少场景手动绑定成本。
func _resolve_context() -> void:
	if player == null and get_parent() is Player:
		player = get_parent() as Player

	if player_build == null and get_parent() is PlayerBuildProxy:
		player_build = (get_parent() as PlayerBuildProxy).player_build

	if equipment_inventory == null:
		if player != null:
			equipment_inventory = player.player_equipment
		elif player_build != null:
			equipment_inventory = player_build.player_equipment


func _get_effect_owner() -> Node:
	if player != null:
		return player

	if get_parent() is PlayerBuildProxy:
		return get_parent()

	return get_parent()


# 给每个装备槽位生成稳定的效果键，避免多个遗物互相覆盖。
func _build_relic_key(slot_index: int, relic: Relic) -> String:
	var relic_id := relic.id
	if relic_id.is_empty():
		relic_id = relic.resource_path
	return "equipment_slot_%s_%s" % [slot_index, relic_id]


# 卸装或刷新前，先把旧效果全部清掉。
func _deactivate_all_relics() -> void:
	var effect_owner := _get_effect_owner()
	if effect_owner == null:
		active_relic_entries.clear()
		return

	for entry in active_relic_entries:
		var relic := entry.get("relic") as Relic
		var relic_key := String(entry.get("key", ""))
		if relic != null:
			relic.deactivate_relic(effect_owner, self, relic_key)

	active_relic_entries.clear()
