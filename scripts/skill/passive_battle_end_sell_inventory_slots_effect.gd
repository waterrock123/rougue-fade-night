class_name PassiveBattleEndSellInventorySlotsEffect
extends PassiveSkillEffect

## 战斗结算时出售背包指定格子的装备。
## “原价出售”使用 Relic.price，而不是普通商店出售时使用的 sell_price。
@export var slot_indices: Array[int] = [0, 1]

var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.run_stats == null:
		return

	active_contexts[_get_context_key(context)] = context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	for value: Variant in active_contexts.values():
		var context: SkillContext = value as SkillContext
		if context != null:
			_sell_target_slots(context)


func _sell_target_slots(context: SkillContext) -> void:
	if context.player_build == null or context.player_build.player_inventory == null:
		return

	var owner: Node = _resolve_owner(context)
	var relic_controller: RelicController = _resolve_relic_controller(context)
	var inventory: Inventory = context.player_build.player_inventory
	var sold_any: bool = false

	for slot_index: int in slot_indices:
		if slot_index < 0 or slot_index >= inventory.slots.size():
			continue

		var slot: Slot = inventory.slots[slot_index]
		if slot == null or slot.item == null:
			continue

		var relic: Relic = slot.item
		var original_price: int = max(relic.price, 0)
		slot.item = null

		if owner != null:
			relic.sell_relic(owner, relic_controller, "%s_sell_%s" % [_get_context_key(context), str(slot_index)])
		context.run_stats.set_gold(context.run_stats.gold + original_price)
		EventBus.relic_removed.emit(relic, "sold")
		EventBus.relic_sold.emit(relic)
		sold_any = true

	if not sold_any:
		return

	AudioController.play_ui_sound(&"sell_item")
	EventBus.inventory_update.emit()
	EventBus.attribute_update.emit()


func _resolve_owner(context: SkillContext) -> Node:
	if context == null or context.skill_controller == null:
		return null
	return context.skill_controller.get_parent()


func _resolve_relic_controller(context: SkillContext) -> RelicController:
	var owner: Node = _resolve_owner(context)
	if owner == null:
		return null
	return owner.get_node_or_null("RelicController") as RelicController


func _get_context_key(context: SkillContext) -> String:
	var controller_id: int = 0
	if context.skill_controller != null:
		controller_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(controller_id), str(context.effect_key)]
