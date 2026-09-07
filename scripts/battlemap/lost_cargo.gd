class_name LostCargo
extends MapObject

const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
const BASE_RELIC_ROLL_WEIGHT: float = 1.0
const DEFAULT_RELIC_KEY_PREFIX: String = "lost_cargo"

@export_group("奖励")
## 打破遗落货物后获得的遗物数量。默认 1 件，后续事件或地图规则可以调高。
@export var reward_count: int = 1
## 开启后，奖励池会读取当前 RunStats.shop.level，保证地图奖励不会超过当前商店进度。
@export var use_current_shop_level: bool = true
## 当没有运行时商店数据，或关闭 use_current_shop_level 时，使用这个等级作为兜底上限。
@export var fixed_max_relic_level: int = 1
## 给当前商店等级加偏移。例如 1 表示“最多当前商店等级 +1 阶”的遗物。
@export var shop_level_offset: int = 0
## 当前商人数据不可用时使用的兜底遗物池。
@export var fallback_relic_pool: RelicPool = DEFAULT_RELIC_POOL
## 遗物进入背包后是否触发“获得遗物”效果。一般保持开启，避免获得类效果漏结算。
@export var trigger_gain_effects: bool = true
## 开启后，货物生成/绑定本局数据时就提前决定奖励，死亡时只负责发放，减少命中瞬间卡顿。
@export var prepare_rewards_on_ready: bool = true
## 成功获得奖励后，在屏幕上方显示一条醒目的获得提示。
@export var show_reward_tip: bool = true
@export var reward_tip_duration: float = 1.8

@export_group("权重")
## 开启后，当前商人的偏好 tag 会提高对应遗物从遗落货物中出现的概率。
@export var use_shopkeeper_tag_weight: bool = true
## 没有商人配置时使用的偏好 tag 权重兜底值。
@export var fallback_preferred_tag_weight_bonus: float = 1.5

var run_stats: RunStats
var cached_candidate_relics: Array[Relic] = []
var prepicked_reward_relics: Array[Relic] = []
var has_prepared_rewards: bool = false
var has_warned_missing_runtime_data: bool = false


func _ready() -> void:
	super._ready()
	if prepare_rewards_on_ready:
		call_deferred("prepare_rewards")


## 地图生成器实例化物件后会调用这里，把本局数据传进来。
func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	if prepare_rewards_on_ready:
		prepare_rewards()


## 提前缓存候选池并预抽奖励。死亡时不再做重型随机和资源筛选，打碎手感会更平滑。
func prepare_rewards(force_refresh: bool = false) -> void:
	if has_prepared_rewards and not force_refresh:
		return

	var stats: RunStats = _get_run_stats()
	if stats == null:
		_warn_missing_runtime_data_once("LostCargo 缺少 RunStats，暂时无法预抽遗落货物奖励。")
		return

	cached_candidate_relics = _get_candidate_relics(stats)
	if cached_candidate_relics.is_empty():
		_warn_missing_runtime_data_once("LostCargo 没有可用遗物候选，请检查 ShopKeeper.relic_pool 或 fallback_relic_pool。")
		return

	prepicked_reward_relics.clear()
	var safe_reward_count: int = max(reward_count, 0)
	for _reward_index: int in range(safe_reward_count):
		var relic_template: Relic = _pick_weighted_relic(cached_candidate_relics, stats)
		if relic_template == null:
			continue

		var reward_relic: Relic = relic_template.duplicate(true) as Relic
		if reward_relic != null:
			prepicked_reward_relics.append(reward_relic)

	has_prepared_rewards = true


func _die() -> void:
	if is_dead:
		return

	_grant_lost_cargo_rewards()
	super._die()


func _grant_lost_cargo_rewards() -> void:
	var stats: RunStats = _get_run_stats()
	if stats == null or stats.player_build == null:
		push_warning("LostCargo 缺少 RunStats 或 PlayerBuild，无法发放遗落货物奖励。")
		return

	if not has_prepared_rewards:
		prepare_rewards()
	if prepicked_reward_relics.is_empty():
		push_warning("LostCargo 没有预抽到可发放遗物，无法发放奖励。")
		return

	var gained_relic_names: Array[String] = []
	for reward_index: int in range(prepicked_reward_relics.size()):
		var reward_relic: Relic = prepicked_reward_relics[reward_index]
		if reward_relic == null:
			continue

		if not stats.player_build.add_relic(reward_relic):
			push_warning("LostCargo 发放遗物失败，背包已满且无法合成：%s" % reward_relic.relic_name)
			continue

		gained_relic_names.append(_get_relic_display_name(reward_relic))
		if trigger_gain_effects:
			var relic_key: String = "%s_%s_%s" % [DEFAULT_RELIC_KEY_PREFIX, str(get_instance_id()), str(reward_index)]
			reward_relic.gain_relic(self, null, relic_key)

	_show_lost_cargo_reward_tip(gained_relic_names)


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
		# 复制资源后引用可能不同，所以用 tag_name 做兜底匹配。
		if tag == target_tag or tag.tag_name == target_tag.tag_name:
			return true

	return false


func _get_shopkeeper(stats: RunStats) -> ShopKeeper:
	if stats == null or stats.shop == null:
		return null
	return stats.shop.shopkeeper


func _show_lost_cargo_reward_tip(gained_relic_names: Array[String]) -> void:
	if not show_reward_tip or gained_relic_names.is_empty():
		return
	if FloatText == null or not FloatText.has_method("show_screen_tip"):
		return

	var message: String = ""
	if gained_relic_names.size() == 1:
		message = "击破了遗落货物，获得了 %s 装备" % gained_relic_names[0]
	else:
		message = "击破了遗落货物，获得了 %s 装备" % "、".join(gained_relic_names)

	FloatText.show_screen_tip(message, reward_tip_duration)


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
