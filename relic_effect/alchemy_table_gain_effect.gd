## 获得时处理原料的通用炼成效果。
## 当前用于“炼药台”：背包无原料时补一件原料并消耗自身；有原料时消耗随机原料并换成加工品。
class_name AlchemyTableGainEffect
extends RelicEffect


@export var material_tag: RelicTag
@export var processed_tag: RelicTag
@export var material_count_to_process: int = 2
@export var grant_material_count_when_empty: int = 1


func on_gain(relic_context: RelicContext, effect_key) -> void:
	var run_stats := _resolve_run_stats(relic_context.owner if relic_context != null else null)
	if run_stats == null or run_stats.player_build == null:
		return
	if material_tag == null:
		return

	var inventory := run_stats.player_build.player_inventory
	if inventory == null:
		return

	var material_slots := _collect_material_slots(inventory)
	if material_slots.is_empty():
		_grant_random_materials(run_stats)
		_consume_own_relic(inventory, relic_context, effect_key)
		return

	RunRng.shuffle_array(material_slots)
	var count = min(max(material_count_to_process, 1), material_slots.size())
	for index in range(count):
		var slot := material_slots[index] as Slot
		var consumed_relic := RelicConsumption.consume_slot(slot, relic_context.owner, relic_context.relic_controller, "%s_material_%s" % [str(effect_key), index], false)
		_grant_processed_relic(run_stats, consumed_relic)

	EventBus.inventory_update.emit()
	EventBus.equipment_update.emit()


func _grant_random_materials(run_stats: RunStats) -> void:
	var material_tags: Array[RelicTag] = []
	material_tags.append(material_tag)
	var candidates := _collect_shop_relic_candidates(run_stats, material_tags, true)
	for _index in range(max(grant_material_count_when_empty, 0)):
		var relic := RunRng.pick(candidates) as Relic
		if relic != null:
			run_stats.player_build.add_relic(relic.duplicate(true) as Relic)


func _grant_processed_relic(run_stats: RunStats, consumed_relic: Relic) -> void:
	var tags: Array[RelicTag] = []
	if processed_tag != null:
		tags.append(processed_tag)

	var candidates := _collect_shop_relic_candidates(run_stats, tags, false)
	if candidates.is_empty():
		return

	var relic := RunRng.pick(candidates) as Relic
	if relic == null:
		return

	var new_relic := relic.duplicate(true) as Relic
	if consumed_relic != null and consumed_relic.leveltip == Relic.LevelTip.LEVELUP:
		new_relic.leveltip = Relic.LevelTip.LEVELUP
	run_stats.player_build.add_relic(new_relic)


func _collect_shop_relic_candidates(run_stats: RunStats, required_tags: Array[RelicTag], exact_material: bool) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	var max_level = run_stats.shop.level
	for relic in run_stats.shop.shopkeeper.relics:
		if relic == null:
			continue
		if relic.level > max_level:
			continue
		if exact_material and not _relic_has_tag(relic, material_tag):
			continue
		if not exact_material and not _matches_any_tag(relic, required_tags):
			continue
		result.append(relic)

	return result


func _collect_material_slots(inventory: Inventory) -> Array[Slot]:
	var result: Array[Slot] = []
	for slot in inventory.slots:
		if slot == null or slot.item == null:
			continue
		if _relic_has_tag(slot.item, material_tag):
			result.append(slot)
	return result


func _consume_own_relic(inventory: Inventory, relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return

	for slot in inventory.slots:
		if slot == null or slot.item == null:
			continue
		if slot.item == relic_context.own_relic:
			RelicConsumption.consume_slot(slot, relic_context.owner, relic_context.relic_controller, "%s_self" % str(effect_key), false)
			EventBus.inventory_update.emit()
			EventBus.equipment_update.emit()
			return


func _matches_any_tag(relic: Relic, required_tags: Array[RelicTag]) -> bool:
	if required_tags.is_empty():
		return true
	for required_tag in required_tags:
		if _relic_has_tag(relic, required_tag):
			return true
	return false


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false
	for relic_tag in relic.tags:
		if relic_tag != null and (relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name):
			return true
	return false


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null
