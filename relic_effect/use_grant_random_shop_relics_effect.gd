## 消耗品使用时从当前商人的货物池里随机获得装备。
## 可配置装备数量、等级筛选方式，以及是否让商人的偏好 tag 提高权重。
class_name UseGrantRandomShopRelicsEffect
extends RelicEffect

const BASE_RELIC_ROLL_WEIGHT := 1.0

@export var relic_count: int = 1
@export var level_offset: int = 0
@export var exact_shop_level: bool = true
@export var use_shopkeeper_tag_weight: bool = true
@export var preferred_tag_weight_bonus: float = 1.5


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_count <= 0:
		return

	var run_stats := _resolve_run_stats(relic_context.owner if relic_context != null else null)
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates := _get_candidate_relics(run_stats)
	if candidates.is_empty():
		return

	for _i in range(relic_count):
		var relic := _pick_weighted_relic(candidates, run_stats)
		if relic == null:
			continue

		run_stats.player_build.add_relic(relic.duplicate(true) as Relic)


func _get_candidate_relics(run_stats: RunStats) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	var target_level = max(run_stats.shop.level + level_offset, 1)
	for relic in run_stats.shop.shopkeeper.relics:
		if relic == null:
			continue
		if exact_shop_level and relic.level != target_level:
			continue
		if not exact_shop_level and relic.level > target_level:
			continue
		result.append(relic)

	# 如果某个商人的当前等阶没有货物，回退为“不高于当前等级”，避免随机结果空转。
	if result.is_empty() and exact_shop_level:
		for relic in run_stats.shop.shopkeeper.relics:
			if relic != null and relic.level <= target_level:
				result.append(relic)

	return result


func _pick_weighted_relic(candidates: Array[Relic], run_stats: RunStats) -> Relic:
	var total_weight := 0.0
	var entries: Array[Dictionary] = []
	for relic in candidates:
		var weight := _get_relic_weight(relic, run_stats)
		total_weight += weight
		entries.append({
			"relic": relic,
			"accumulated_weight": total_weight,
		})

	if entries.is_empty() or total_weight <= 0.0:
		return null

	# 战斗内使用消耗品的随机结果不接入 RunRng，避免推进商店/地图随机流。
	var roll := randf_range(0.0, total_weight)
	for entry in entries:
		if float(entry["accumulated_weight"]) >= roll:
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
		if preferred_tag == null:
			continue
		if _relic_has_tag(relic, preferred_tag):
			count += 1
	return count


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name:
			return true
	return false


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()

	return null
