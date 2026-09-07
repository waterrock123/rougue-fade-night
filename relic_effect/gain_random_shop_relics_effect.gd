## 获得遗物时，从当前商人的货物池里随机获得额外遗物。
## 用于“获得时再获得随机同等阶装备”这类一次性奖励。
class_name GainRandomShopRelicsEffect
extends RelicEffect

const BASE_RELIC_ROLL_WEIGHT := 1.0

@export var min_relic_count: int = 1
@export var max_relic_count: int = 3
@export_range(0.0, 1.0, 0.0001) var jackpot_chance: float = 0.005
@export var jackpot_relic_count: int = 10
@export var exact_own_level: bool = true
## 开启后以当前商店等级为目标等级，适合“获得一件等同商店等级的装备”。
@export var use_current_shop_level: bool = false
## 开启后，发放出的遗物会直接变为升级态。
@export var grant_as_levelup: bool = false
@export var use_shopkeeper_tag_weight: bool = true
@export var preferred_tag_weight_bonus: float = 1.5


func on_gain(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null:
		return

	var run_stats := _resolve_run_stats(relic_context.owner)
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates := _get_candidate_relics(run_stats, relic_context.own_relic)
	if candidates.is_empty():
		return

	var relic_count := _roll_relic_count()
	for _index in range(relic_count):
		var relic := _pick_weighted_relic(candidates, run_stats)
		if relic == null:
			continue

		var granted_relic := relic.duplicate(true) as Relic
		if grant_as_levelup:
			granted_relic.leveltip = Relic.LevelTip.LEVELUP
		run_stats.player_build.add_relic(granted_relic)


func _roll_relic_count() -> int:
	if RunRng.randf() <= jackpot_chance:
		return max(jackpot_relic_count, 0)

	var from_count: int = min(min_relic_count, max_relic_count)
	var to_count: int = max(min_relic_count, max_relic_count)
	return max(RunRng.randi_range(from_count, to_count), 0)


func _get_candidate_relics(run_stats: RunStats, own_relic: Relic) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats.shop == null or run_stats.shop.shopkeeper == null or own_relic == null:
		return result

	var target_level: int = own_relic.level
	if use_current_shop_level:
		target_level = max(run_stats.shop.level, 1)

	var source_relics: Array[Relic] = run_stats.shop.shopkeeper.get_available_relics(target_level)
	for relic in source_relics:
		if relic == null:
			continue
		if exact_own_level and relic.level != target_level:
			continue
		if not exact_own_level and relic.level > target_level:
			continue
		result.append(relic)

	# 某个商人缺少该等阶货物时，回退到“不高于该等阶”，避免效果空转。
	if result.is_empty() and exact_own_level:
		for relic in source_relics:
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

	# 获得装备属于局外运营随机，接入 RunRng 以便读档后结果稳定。
	var roll := RunRng.randf_range(0.0, total_weight)
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
		if preferred_tag != null and _relic_has_tag(relic, preferred_tag):
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
