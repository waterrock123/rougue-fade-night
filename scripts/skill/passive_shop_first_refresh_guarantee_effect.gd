class_name PassiveShopFirstRefreshGuaranteeEffect
extends PassiveSkillEffect

## 本次修整期第一次刷新商店时，替换商品为指定类型的保底装备。
## same_level_relic 会严格取当前商店等级；unique_relic 会从不高于当前等级的独特装备中抽取。
@export var guarantee_same_level_relic: bool = true
@export var guarantee_unique_relic: bool = false

var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.run_stats == null:
		return
	# 商店被动由 Run 下的 PlayerBuildProxy 管理，战斗 Player 不重复监听商店信号。
	if context.caster != null:
		return

	var context_key: String = _get_context_key(context)
	active_contexts[context_key] = context
	if not EventBus.shop_refreshed.is_connected(_on_shop_refreshed):
		EventBus.shop_refreshed.connect(_on_shop_refreshed)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.shop_refreshed.is_connected(_on_shop_refreshed):
		EventBus.shop_refreshed.disconnect(_on_shop_refreshed)


func _on_shop_refreshed(shop: Shop) -> void:
	if shop == null:
		return

	var changed: bool = false
	for value: Variant in active_contexts.values():
		var context: SkillContext = value as SkillContext
		if context == null or context.run_stats == null or context.run_stats.shop != shop:
			continue
		if context.run_stats.get_shop_refresh_count_this_rest_period() > 0:
			continue

		var used_slots: Array[int] = []
		if guarantee_same_level_relic:
			var same_level_relic: Relic = _pick_same_level_relic(shop)
			if same_level_relic != null and _replace_random_slot(shop, same_level_relic, used_slots):
				changed = true

		if guarantee_unique_relic:
			var unique_relic: Relic = _pick_unique_relic(shop)
			if unique_relic != null and _replace_random_slot(shop, unique_relic, used_slots):
				changed = true

	if changed:
		EventBus.shop_inventory_update.emit()


func _pick_same_level_relic(shop: Shop) -> Relic:
	if shop.shopkeeper == null:
		return null
	var candidates: Array[Relic] = shop.shopkeeper.get_available_relics_by_level(shop.level)
	var picked_value: Variant = RunRng.pick(candidates)
	var template: Relic = picked_value as Relic
	return template.duplicate(true) as Relic if template != null else null


func _pick_unique_relic(shop: Shop) -> Relic:
	if shop.shopkeeper == null:
		return null

	var candidates: Array[Relic] = []
	for relic: Relic in shop.shopkeeper.get_available_relics(shop.level):
		if relic != null and relic.relic_type == Relic.RelicType.UNIQUE:
			candidates.append(relic)

	var picked_value: Variant = RunRng.pick(candidates)
	var template: Relic = picked_value as Relic
	return template.duplicate(true) as Relic if template != null else null


func _replace_random_slot(shop: Shop, relic: Relic, used_slots: Array[int]) -> bool:
	if shop == null or relic == null or shop.current_slot.is_empty():
		return false

	var candidates: Array[int] = []
	for index: int in range(shop.current_slot.size()):
		if not used_slots.has(index):
			candidates.append(index)
	if candidates.is_empty():
		candidates.append(0)

	var slot_index: int = int(RunRng.pick(candidates))
	var slot: Slot = shop.current_slot[slot_index]
	if slot == null:
		slot = Slot.new()
		shop.current_slot[slot_index] = slot
	slot.item = relic
	used_slots.append(slot_index)
	return true


func _get_context_key(context: SkillContext) -> String:
	var controller_id: int = 0
	if context.skill_controller != null:
		controller_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(controller_id), str(context.effect_key)]
