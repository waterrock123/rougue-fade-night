class_name GoldenFlashPickup
extends MapPickup

## 金色闪光：拾取后获得一件不超过当前商店等阶的随机遗物。
## 奖励会在生成后尽早预抽，拾取瞬间只负责发放，减少战斗中卡顿。

const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
const BASE_RELIC_ROLL_WEIGHT: float = 1.0
const DEFAULT_RELIC_KEY_PREFIX: String = "golden_flash"

@export_group("奖励")
@export var use_current_shop_level: bool = true
@export var fixed_max_relic_level: int = 1
@export var shop_level_offset: int = 0
@export var fallback_relic_pool: RelicPool = DEFAULT_RELIC_POOL
@export var trigger_gain_effects: bool = true
@export var prepare_reward_on_ready: bool = true

@export_group("权重")
@export var use_shopkeeper_tag_weight: bool = true
@export var fallback_preferred_tag_weight_bonus: float = 1.5

var run_stats: RunStats
var cached_candidate_relics: Array[Relic] = []
var prepared_reward_relic: Relic
var has_prepared_reward: bool = false
var has_warned_missing_runtime_data: bool = false


func _ready() -> void:
	if pickup_display_name.is_empty():
		pickup_display_name = "金色闪光"
	super._ready()
	if prepare_reward_on_ready:
		call_deferred("prepare_reward")


## 地图物件或测试场景可以手动传入本局数据，避免拾取时再向上查找。
func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	if prepare_reward_on_ready:
		prepare_reward()


func prepare_reward(force_refresh: bool = false) -> void:
	if has_prepared_reward and not force_refresh:
		return

	var stats: RunStats = _get_run_stats()
	if stats == null:
		_warn_missing_runtime_data_once("GoldenFlashPickup 缺少 RunStats，暂时无法预抽奖励。")
		return

	cached_candidate_relics = _get_candidate_relics(stats)
	if cached_candidate_relics.is_empty():
		_warn_missing_runtime_data_once("GoldenFlashPickup 没有可用遗物候选，请检查商人遗物池或 fallback_relic_pool。")
		return

	var relic_template: Relic = _pick_weighted_relic(cached_candidate_relics, stats)
	prepared_reward_relic = null
	if relic_template != null:
		prepared_reward_relic = relic_template.duplicate(true) as Relic
	has_prepared_reward = prepared_reward_relic != null


func _apply_pickup(_collector: Entity) -> void:
	var stats: RunStats = _get_run_stats()
	if stats == null or stats.player_build == null:
		show_collected_tip("没有找到可发放的装备")
		return

	if not has_prepared_reward:
		prepare_reward()
	if prepared_reward_relic == null:
		show_collected_tip("没有找到可发放的装备")
		return

	var reward_relic: Relic = prepared_reward_relic
	prepared_reward_relic = null
	has_prepared_reward = false

	if not stats.player_build.add_relic(reward_relic):
		show_collected_tip("背包已满，装备未能进入背包")
		return

	if trigger_gain_effects:
		var relic_key: String = "%s_%s" % [DEFAULT_RELIC_KEY_PREFIX, str(get_instance_id())]
		reward_relic.gain_relic(self, null, relic_key)

	show_collected_tip("获得了 %s 装备" % _get_relic_display_name(reward_relic))


func _get_candidate_relics(stats: RunStats) -> Array[Relic]:
	var max_level: int = _get_max_relic_level(stats)
	var shopkeeper: ShopKeeper = _get_shopkeeper(stats)
	if shopkeeper != null:
		return shopkeeper.get_available_relics(max_level)

	if fallback_relic_pool != null:
		return fallback_relic_pool.get_relics_up_to_level(max_level)

	return []


func _get_max_relic_level(stats: RunStats) -> int:
	if use_current_shop_level and stats != null and stats.shop != null:
		return max(stats.shop.level + shop_level_offset, 1)

	return max(fixed_max_relic_level, 1)


func _pick_weighted_relic(candidate_relics: Array[Relic], stats: RunStats) -> Relic:
	var total_weight: float = 0.0
	var weighted_entries: Array[Dictionary] = []

	for relic: Relic in candidate_relics:
		if relic == null:
			continue

		var weight: float = _get_relic_roll_weight(relic, stats)
		total_weight += weight
		weighted_entries.append({
			"relic": relic,
			"accumulated_weight": total_weight,
		})

	if weighted_entries.is_empty() or total_weight <= 0.0:
		return null

	var roll: float = _roll_seeded_float_range(0.0, total_weight)
	for entry: Dictionary in weighted_entries:
		if float(entry.get("accumulated_weight", 0.0)) >= roll:
			return entry.get("relic") as Relic

	return weighted_entries[weighted_entries.size() - 1].get("relic") as Relic


func _get_relic_roll_weight(relic: Relic, stats: RunStats) -> float:
	var shopkeeper: ShopKeeper = _get_shopkeeper(stats)
	var weight: float = BASE_RELIC_ROLL_WEIGHT
	if shopkeeper != null:
		weight = shopkeeper.get_relic_base_weight(relic, BASE_RELIC_ROLL_WEIGHT)

	if not use_shopkeeper_tag_weight:
		return max(weight, 0.01)

	var matched_tag_count: int = _get_preferred_tag_match_count(relic, shopkeeper)
	if matched_tag_count <= 0:
		return max(weight, 0.01)

	var tag_weight_bonus: float = fallback_preferred_tag_weight_bonus
	if shopkeeper != null:
		tag_weight_bonus = shopkeeper.preferred_tag_weight_bonus

	weight += float(matched_tag_count) * tag_weight_bonus
	return max(weight, 0.01)


func _get_preferred_tag_match_count(relic: Relic, shopkeeper: ShopKeeper) -> int:
	if relic == null or shopkeeper == null:
		return 0
	if shopkeeper.havetag.is_empty() or relic.tags.is_empty():
		return 0

	var result: int = 0
	for preferred_tag: RelicTag in shopkeeper.havetag:
		if preferred_tag == null:
			continue
		if _relic_has_tag(relic, preferred_tag):
			result += 1

	return result


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for tag: RelicTag in relic.tags:
		if tag == null:
			continue
		if tag == target_tag or tag.tag_name == target_tag.tag_name:
			return true

	return false


func _get_shopkeeper(stats: RunStats) -> ShopKeeper:
	if stats == null or stats.shop == null:
		return null
	return stats.shop.shopkeeper


func _get_relic_display_name(relic: Relic) -> String:
	if relic == null:
		return "未知装备"
	if not relic.relic_name.strip_edges().is_empty():
		return relic.relic_name
	if not relic.id.strip_edges().is_empty():
		return relic.id
	return "未知装备"


func _get_run_stats() -> RunStats:
	if run_stats != null:
		return run_stats

	run_stats = _find_run_stats_from_ancestors()
	return run_stats


func _find_run_stats_from_ancestors() -> RunStats:
	var current_node: Node = self
	while current_node != null:
		var value: Variant = _get_node_property(current_node, "run_stats")
		if value is RunStats:
			return value as RunStats
		current_node = current_node.get_parent()

	return null


func _get_node_property(node: Node, property_name: String) -> Variant:
	if node == null:
		return null

	for property_info: Dictionary in node.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return node.get(property_name)

	return null


func _roll_seeded_float_range(from: float, to: float) -> float:
	if RunRng != null and RunRng.seed_value != 0:
		return RunRng.randf_range(from, to)

	return randf_range(from, to)


func _warn_missing_runtime_data_once(message: String) -> void:
	if has_warned_missing_runtime_data:
		return

	has_warned_missing_runtime_data = true
	push_warning(message)
