## 获得遗物时批量消耗背包中指定标签的装备，再按规则逐件发放替代品。
## 用于“用具加工全部原料”这类一次性转化，消耗始终走 RelicConsumption，确保原料自身的被消耗效果有效。
class_name GainConsumeAllTaggedRelicsEffect
extends RelicEffect

enum RewardMode {
	UPGRADE_CONSUMED_RELIC,
	HIGHER_LEVEL_TAGGED_RELIC,
}

@export var consume_tag: RelicTag
@export var reward_mode: RewardMode = RewardMode.UPGRADE_CONSUMED_RELIC
@export var output_required_tags: Array[RelicTag] = []
@export var maximum_reward_level: int = 6
## 升级态拥有者跳过基础版本，避免基础、升级两条效果重复消耗同一批原料。
@export var ignore_when_owner_levelup: bool = false


func on_gain(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or consume_tag == null:
		return
	if ignore_when_owner_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var player_build: PlayerBuild = _get_player_build(relic_context)
	var run_stats: RunStats = _resolve_run_stats(relic_context.owner)
	if player_build == null or player_build.player_inventory == null:
		return

	var material_slots: Array[Slot] = _collect_matching_slots(player_build.player_inventory)
	if material_slots.is_empty():
		return

	# 先预生成所有奖励；某一阶缺少合法产物时不会吞掉对应原料。
	var conversions: Array[Dictionary] = []
	for slot: Slot in material_slots:
		var consumed_relic: Relic = slot.item
		var reward: Relic = _build_reward(run_stats, consumed_relic)
		if reward != null:
			conversions.append({"slot": slot, "reward": reward})

	for index: int in range(conversions.size()):
		var conversion: Dictionary = conversions[index]
		var slot: Slot = conversion.get("slot") as Slot
		var reward: Relic = conversion.get("reward") as Relic
		if slot == null or reward == null:
			continue
		RelicConsumption.consume_slot(
			slot,
			relic_context.owner,
			relic_context.relic_controller,
			"%s_material_%s" % [str(effect_key), str(index)],
			false
		)
		player_build.add_relic(reward)

	if not conversions.is_empty():
		EventBus.inventory_update.emit()
		EventBus.equipment_update.emit()


func _collect_matching_slots(inventory: Inventory) -> Array[Slot]:
	var result: Array[Slot] = []
	for slot: Slot in inventory.slots:
		if slot != null and slot.item != null and _relic_has_tag(slot.item, consume_tag):
			result.append(slot)
	return result


func _build_reward(run_stats: RunStats, consumed_relic: Relic) -> Relic:
	if consumed_relic == null:
		return null
	if reward_mode == RewardMode.UPGRADE_CONSUMED_RELIC:
		var upgraded: Relic = consumed_relic.duplicate(true) as Relic
		upgraded.leveltip = Relic.LevelTip.LEVELUP
		return upgraded

	var candidates: Array[Relic] = _collect_higher_level_candidates(run_stats, consumed_relic)
	if candidates.is_empty():
		return null
	var selected: Relic = RunRng.pick(candidates) as Relic
	return selected.duplicate(true) as Relic if selected != null else null


func _collect_higher_level_candidates(run_stats: RunStats, consumed_relic: Relic) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats == null or run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	var target_level: int = min(consumed_relic.level + 1, maximum_reward_level)
	for relic: Relic in run_stats.shop.shopkeeper.get_available_relics_by_level(target_level):
		if relic != null and _has_any_output_tag(relic):
			result.append(relic)
	return result


func _has_any_output_tag(relic: Relic) -> bool:
	if output_required_tags.is_empty():
		return true
	for tag: RelicTag in output_required_tags:
		if _relic_has_tag(relic, tag):
			return true
	return false


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false
	for tag: RelicTag in relic.tags:
		if tag != null and (tag == target_tag or tag.tag_name == target_tag.tag_name):
			return true
	return false


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context != null and relic_context.relic_controller != null:
		return relic_context.relic_controller.player_build
	var run_stats: RunStats = _resolve_run_stats(relic_context.owner if relic_context != null else null)
	return run_stats.player_build if run_stats != null else null


func _resolve_run_stats(owner: Node) -> RunStats:
	var node: Node = owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats as RunStats
		node = node.get_parent()
	return null
