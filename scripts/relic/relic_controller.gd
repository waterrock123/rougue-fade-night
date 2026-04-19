class_name RelicController
extends Node


@export var equipment_inventory: Equipment
@export var player: Player

var active_relic_entries: Array[Dictionary] = []


func _ready() -> void:
	_resolve_context()

	if not EventBus.equipment_update.is_connected(_on_equipment_changed):
		EventBus.equipment_update.connect(_on_equipment_changed)

	call_deferred("refresh_all")


# 提供给 RelicEffect 使用的统一查询入口。
func get_stats_controller() -> StatsController:
	var effect_owner := _get_effect_owner()
	if effect_owner == null:
		return null

	return effect_owner.stats_controller


# 根据当前装备栏状态刷新所有遗物效果。
func refresh_all() -> void:
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


# 自动从父节点补齐引用，减少场景手动绑定成本。
func _resolve_context() -> void:
	if player == null and get_parent() is Player:
		player = get_parent() as Player

	if equipment_inventory == null and player != null:
		equipment_inventory = player.player_equipment


func _get_effect_owner() -> Entity:
	if player != null:
		return player

	return get_parent() as Entity


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
