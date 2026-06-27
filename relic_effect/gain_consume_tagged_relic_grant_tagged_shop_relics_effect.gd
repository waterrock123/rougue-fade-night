## 遗物效果：获得本遗物时，消耗背包中带指定标签的一件遗物，并从当前商人货池中获得若干带指定标签的遗物。
## 适合“用具把原料加工成弹药/成品”这类一次性获得效果；消耗动作统一走 RelicConsumption，确保原料自身的“被消耗”效果也能触发。
class_name GainConsumeTaggedRelicGrantTaggedShopRelicsEffect
extends RelicEffect

const BASE_RELIC_ROLL_WEIGHT := 1.0

@export var consume_tag: RelicTag
@export var grant_required_tags: Array[RelicTag] = []
@export var grant_count: int = 3
@export var same_level_as_consumed: bool = true
@export var use_shopkeeper_tag_weight: bool = true
@export var preferred_tag_weight_bonus: float = 1.5


func on_gain(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null:
		return

	var run_stats: RunStats = _resolve_run_stats(relic_context.owner)
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_inventory == null:
		return

	var material_slots: Array[Slot] = _collect_consume_slots(run_stats.player_build.player_inventory)
	if material_slots.is_empty():
		return

	RunRng.shuffle_array(material_slots)
	var target_slot: Slot = material_slots[0]
	var consumed_relic: Relic = target_slot.item
	if consumed_relic == null:
		return

	var candidates: Array[Relic] = _get_candidate_relics(run_stats, consumed_relic)
	if candidates.is_empty():
		return

	# 先确认奖励池存在，再消耗原料，避免“吃了原料却没有产物”的体验。
	RelicConsumption.consume_slot(
		target_slot,
		relic_context.owner,
		relic_context.relic_controller,
		"%s_consumed_material" % str(effect_key),
		false
	)

	for _index in range(max(grant_count, 0)):
		var template: Relic = _pick_weighted_relic(candidates, run_stats)
		if template == null:
			continue

		run_stats.player_build.add_relic(template.duplicate(true) as Relic)

	EventBus.inventory_update.emit()
	EventBus.equipment_update.emit()
	EventBus.attribute_update.emit()


func _collect_consume_slots(inventory: Inventory) -> Array[Slot]:
	var result: Array[Slot] = []
	if consume_tag == null:
		return result

	for slot in inventory.slots:
		if slot == null or slot.item == null:
			continue
		if _relic_has_tag(slot.item, consume_tag):
			result.append(slot)

	return result


func _get_candidate_relics(run_stats: RunStats, consumed_relic: Relic) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats.shop == null or run_stats.shop.shopkeeper == null or consumed_relic == null:
		return result

	for relic in run_stats.shop.shopkeeper.relics:
		if relic == null:
			continue
		if same_level_as_consumed and relic.level != consumed_relic.level:
			continue
		if not _has_any_required_tag(relic):
			continue
		result.append(relic)

	return result


func _has_any_required_tag(relic: Relic) -> bool:
	if grant_required_tags.is_empty():
		return true

	for required_tag in grant_required_tags:
		if _relic_has_tag(relic, required_tag):
			return true

	return false


func _pick_weighted_relic(candidates: Array[Relic], run_stats: RunStats) -> Relic:
	var total_weight := 0.0
	var entries: Array[Dictionary] = []

	for relic in candidates:
		var weight: float = _get_relic_weight(relic, run_stats)
		total_weight += weight
		entries.append({
			"relic": relic,
			"accumulated_weight": total_weight,
		})

	if entries.is_empty() or total_weight <= 0.0:
		return null

	# 获得装备属于局外运营随机，接入 RunRng 以便读档后结果稳定。
	var roll: float = RunRng.randf_range(0.0, total_weight)
	for entry in entries:
		var accumulated_weight: float = float(entry["accumulated_weight"])
		if accumulated_weight >= roll:
			return entry["relic"] as Relic

	return entries.back()["relic"] as Relic


func _get_relic_weight(relic: Relic, run_stats: RunStats) -> float:
	var weight := BASE_RELIC_ROLL_WEIGHT
	if use_shopkeeper_tag_weight and run_stats.shop != null and run_stats.shop.shopkeeper != null:
		weight += _get_preferred_tag_match_count(relic, run_stats.shop.shopkeeper) * preferred_tag_weight_bonus
	return max(weight, 0.01)


func _get_preferred_tag_match_count(relic: Relic, shopkeeper: ShopKeeper) -> int:
	if relic == null or shopkeeper == null:
		return 0

	var count := 0
	for preferred_tag in shopkeeper.havetag:
		if preferred_tag != null and _relic_has_tag(relic, preferred_tag):
			count += 1
	return count


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name:
			return true

	return false


func _resolve_run_stats(owner: Node) -> RunStats:
	var node: Node = owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats as RunStats
		node = node.get_parent()

	return null
