## 遗物被“消耗”时，从当前商人的货物池里随机获得装备。
## 适合铸铁、钢铁这类原料：被用具/技能作为材料吃掉后，反过来吐出一件新装备。
class_name ConsumedGrantRandomShopRelicsEffect
extends RelicEffect

const BASE_RELIC_ROLL_WEIGHT := 1.0

@export var relic_count: int = 1
## 固定最大等阶。use_shop_level_as_max_level 为 false 时使用它；例如铸铁基础态“不高于 lv2”。
@export var max_relic_level: int = 2
## 开启后使用当前商店等级作为最大等阶；例如铸铁升级态“不高于商店等阶”。
@export var use_shop_level_as_max_level: bool = false
@export var shop_level_offset: int = 0
## 若为 true，升级态遗物会跳过这个基础效果，交给 great_effects 里的替代效果处理。
@export var ignore_when_relic_levelup: bool = false
@export var use_shopkeeper_tag_weight: bool = true
@export var preferred_tag_weight_bonus: float = 1.5


func on_consumed(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null:
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return
	if relic_count <= 0:
		return

	var run_stats = _resolve_run_stats(relic_context.owner)
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates = _get_candidate_relics(run_stats)
	if candidates.is_empty():
		return

	for _index in range(relic_count):
		var relic = _pick_weighted_relic(candidates, run_stats)
		if relic == null:
			continue

		run_stats.player_build.add_relic(relic.duplicate(true) as Relic)


func _get_candidate_relics(run_stats: RunStats) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats == null or run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	var target_level = _get_target_max_level(run_stats)
	for relic in run_stats.shop.shopkeeper.relics:
		if relic == null:
			continue
		if relic.level <= target_level:
			result.append(relic)

	return result


func _get_target_max_level(run_stats: RunStats) -> int:
	if use_shop_level_as_max_level and run_stats != null and run_stats.shop != null:
		return max(run_stats.shop.level + shop_level_offset, 1)

	return max(max_relic_level, 1)


func _pick_weighted_relic(candidates: Array[Relic], run_stats: RunStats) -> Relic:
	var total_weight = 0.0
	var entries: Array[Dictionary] = []
	for relic in candidates:
		var weight = _get_relic_weight(relic, run_stats)
		total_weight += weight
		entries.append({
			"relic": relic,
			"accumulated_weight": total_weight,
		})

	if entries.is_empty() or total_weight <= 0.0:
		return null

	# 被消耗触发可能发生在战斗内，先不推进 RunRng，避免影响地图/商店随机序列。
	var roll = randf_range(0.0, total_weight)
	for entry in entries:
		if float(entry["accumulated_weight"]) >= roll:
			return entry["relic"] as Relic

	return entries.back()["relic"] as Relic


func _get_relic_weight(relic: Relic, run_stats: RunStats) -> float:
	var weight = BASE_RELIC_ROLL_WEIGHT
	if use_shopkeeper_tag_weight and run_stats != null and run_stats.shop != null and run_stats.shop.shopkeeper != null:
		weight += _get_preferred_tag_match_count(relic, run_stats.shop.shopkeeper) * preferred_tag_weight_bonus
	return max(weight, 0.01)


func _get_preferred_tag_match_count(relic: Relic, shopkeeper: ShopKeeper) -> int:
	if relic == null or shopkeeper == null:
		return 0

	var count = 0
	for preferred_tag in shopkeeper.havetag:
		if preferred_tag == null:
			continue
		if _relic_has_tag(relic, preferred_tag):
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
	var node = owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()

	return null
