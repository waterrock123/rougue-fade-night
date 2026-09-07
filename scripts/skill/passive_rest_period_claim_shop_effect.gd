class_name PassiveRestPeriodClaimShopEffect
extends PassiveSkillEffect

## 进入修整期时领取当前商店中所有可以放入玩家构筑的装备，并禁止本局商店刷新。
## 这是运行时效果，不会直接修改商店资源的初始配置。
var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.run_stats == null:
		return

	var context_key: String = _get_context_key(context)
	active_contexts[context_key] = context
	context.run_stats.set_shop_refresh_disabled(context_key, true)
	if not EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.connect(_on_rest_period_started)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	var context_key: String = _get_context_key(context)
	active_contexts.erase(context_key)
	if context.run_stats != null:
		context.run_stats.set_shop_refresh_disabled(context_key, false)

	if active_contexts.is_empty() and EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.disconnect(_on_rest_period_started)


func _on_rest_period_started() -> void:
	for value: Variant in active_contexts.values():
		var context: SkillContext = value as SkillContext
		if context != null:
			_claim_shop_items(context)


func _claim_shop_items(context: SkillContext) -> void:
	var run_stats: RunStats = context.run_stats
	var player_build: PlayerBuild = context.player_build
	if run_stats == null or player_build == null or run_stats.shop == null:
		return

	var owner: Node = _resolve_owner(context)
	var relic_controller: RelicController = _resolve_relic_controller(context)
	var claimed_any: bool = false
	var shop: Shop = run_stats.shop

	for slot_index: int in range(shop.current_slot.size()):
		var slot: Slot = shop.current_slot[slot_index]
		if slot == null or slot.item == null:
			continue

		var relic: Relic = slot.item
		if not player_build.can_accept_relic(relic):
			continue
		if not player_build.add_relic(relic):
			continue

		# 和正常获得装备一样执行一次 gain 效果，但不支付金币。
		if owner != null:
			relic.gain_relic(owner, relic_controller, "%s_shop_%s" % [_get_context_key(context), str(slot_index)])
		slot.item = null
		shop.set_slot_frozen(slot_index, false)
		claimed_any = true

	if claimed_any and EventBus != null:
		EventBus.shop_inventory_update.emit()


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
