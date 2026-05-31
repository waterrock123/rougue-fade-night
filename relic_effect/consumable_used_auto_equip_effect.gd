## 使用消耗品后，从背包里自动装备另一个消耗品。
## 用于“古怪餐盘”：让玩家在战斗中连续使用多个消耗品，但限制每场触发次数。
class_name ConsumableUsedAutoEquipEffect
extends RelicEffect

@export var max_trigger_count: int = 3
@export var levelup_max_trigger_count: int = 5

var active_contexts: Dictionary = {}
var trigger_counts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return

	active_contexts[str(effect_key)] = relic_context
	trigger_counts[str(effect_key)] = 0
	if not EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.connect(_on_consumable_used)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	trigger_counts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.disconnect(_on_consumable_used)


func _on_consumable_used(_relic: Relic, user: Entity) -> void:
	if user == null:
		return

	for key in active_contexts.keys():
		var relic_context := active_contexts[key] as RelicContext
		if relic_context == null or relic_context.owner != user:
			continue
		if int(trigger_counts.get(key, 0)) >= _get_max_trigger_count(relic_context):
			continue

		trigger_counts[key] = int(trigger_counts.get(key, 0)) + 1
		_auto_equip_after_current_use.call_deferred(relic_context)


func _auto_equip_after_current_use(relic_context: RelicContext) -> void:
	var owner := relic_context.owner as Entity
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return

	await owner.get_tree().process_frame

	var player_build := _get_player_build(relic_context)
	if player_build == null or player_build.player_inventory == null or player_build.player_equipment == null:
		return

	var source_slot := _find_inventory_consumable_slot(player_build.player_inventory)
	var target_slot := _find_empty_equipment_slot(player_build.player_equipment)
	if source_slot == null or target_slot == null:
		return

	target_slot.item = source_slot.item
	source_slot.item = null
	EventBus.inventory_update.emit()
	EventBus.equipment_update.emit()


func _find_inventory_consumable_slot(inventory: Inventory) -> Slot:
	for slot in inventory.slots:
		if slot != null and slot.item != null and slot.item.is_consumable:
			return slot
	return null


func _find_empty_equipment_slot(equipment: Equipment) -> Slot:
	for slot in equipment.equip_slots:
		if slot != null and slot.item == null:
			return slot
	return null


func _get_max_trigger_count(relic_context: RelicContext) -> int:
	if relic_context != null and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return max(levelup_max_trigger_count, 0)
	return max(max_trigger_count, 0)


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is Entity:
		var stats_controller := (relic_context.owner as Entity).stats_controller
		return stats_controller.player_build if stats_controller != null else null
	return null
