## 遗物被消耗时，从当前商人的货物池中获得带指定 tag 的同等阶装备。
## 用于“钢铁”这类原料：被消耗后转化成凶器/守御装备。
class_name ConsumedGrantTaggedShopRelicEffect
extends RelicEffect

@export var required_tags: Array[RelicTag] = []
@export var relic_count: int = 1
@export var same_level_as_consumed: bool = true
@export var levelup_grants_levelup_relic: bool = true
@export var ignore_when_relic_levelup: bool = false


func on_consumed(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return
	if ignore_when_relic_levelup and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var run_stats := _resolve_run_stats(relic_context.owner)
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates := _get_candidates(run_stats, relic_context.own_relic)
	if candidates.is_empty():
		return

	for _index in range(max(relic_count, 1)):
		var relic = RunRng.pick(candidates) as Relic
		if relic == null:
			continue

		var new_relic := relic.duplicate(true) as Relic
		if levelup_grants_levelup_relic and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
			new_relic.leveltip = Relic.LevelTip.LEVELUP
		run_stats.player_build.add_relic(new_relic)


func _get_candidates(run_stats: RunStats, own_relic: Relic) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	for relic in run_stats.shop.shopkeeper.relics:
		if relic == null or relic.id == own_relic.id:
			continue
		if same_level_as_consumed and relic.level != own_relic.level:
			continue
		if not _has_any_required_tag(relic):
			continue
		result.append(relic)

	return result


func _has_any_required_tag(relic: Relic) -> bool:
	if required_tags.is_empty():
		return true

	for required_tag in required_tags:
		if required_tag == null:
			continue
		for relic_tag in relic.tags:
			if relic_tag != null and (relic_tag == required_tag or relic_tag.tag_name == required_tag.tag_name):
				return true
	return false


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null
