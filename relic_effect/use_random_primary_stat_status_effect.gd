class_name UseRandomPrimaryStatStatusEffect
extends RelicEffect

## 消耗品使用时，随机若干次一级属性并转成战斗内状态。
## 当前用于“酒”：随机属性 +1 重复多次，持续到本场战斗结束。

const DEFAULT_PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

@export var random_primary_stats: Array[StringName] = DEFAULT_PRIMARY_STATS
@export var roll_count: int = 5
## 小于 0 时升级态仍使用 roll_count；大于等于 0 时升级态改用这个次数。
@export var levelup_roll_count: int = -1
@export var stat_amount: float = 1.0
## 小于 0 表示持续到战斗结束。
@export var status_duration: float = -1.0
@export var status_name: String = "随机属性提升"
@export_multiline var status_desc: String = "本场战斗中获得随机一级属性提升。"
@export var status_icon: Texture2D


func on_use(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or random_primary_stats.is_empty() or stat_amount == 0.0:
		return

	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null:
		return

	var totals: Dictionary = _roll_stat_totals(_get_roll_count(relic_context))
	if totals.is_empty():
		return

	var status_data: StatusData = _build_status_data(str(effect_key), totals)
	status_controller.add_status(status_data, relic_context.owner, str(effect_key), 1, status_duration)


func _roll_stat_totals(count: int) -> Dictionary:
	var totals: Dictionary = {}
	for _index in range(max(count, 0)):
		var stat_name: StringName = _pick_random_stat()
		if stat_name == &"":
			continue

		totals[stat_name] = float(totals.get(stat_name, 0.0)) + stat_amount
	return totals


func _build_status_data(effect_key: String, totals: Dictionary) -> StatusData:
	var stat_effect: StatusAddStatsEffect = StatusAddStatsEffect.new()
	stat_effect.stat_values = totals

	var status_data: StatusData = StatusData.new()
	status_data.id = StringName("%s_random_primary_stats" % effect_key)
	status_data.status_name = status_name
	status_data.desc = _build_status_desc(totals)
	status_data.icon = status_icon
	status_data.duration = status_duration
	status_data.max_stacks = 1
	status_data.stack_mode = StatusData.StackMode.REPLACE
	status_data.refresh_duration_on_reapply = false
	status_data.effects = [stat_effect]
	return status_data


func _build_status_desc(totals: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_name in totals.keys():
		parts.append("%s +%s" % [_get_primary_stat_display_name(StringName(stat_name)), str(totals[stat_name])])

	if parts.is_empty():
		return status_desc
	return "%s\n%s" % [status_desc, "，".join(parts)]


func _get_roll_count(relic_context: RelicContext) -> int:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_roll_count >= 0:
			return levelup_roll_count
	return roll_count


func _pick_random_stat() -> StringName:
	if random_primary_stats.is_empty():
		return &""
	var index: int = randi_range(0, random_primary_stats.size() - 1)
	return random_primary_stats[index]


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null or relic_context.owner == null:
		return null
	if relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	return relic_context.owner.get_node_or_null("StatusController") as StatusController


func _get_primary_stat_display_name(stat_name: StringName) -> String:
	match stat_name:
		&"strength":
			return "力量"
		&"dexterity":
			return "敏捷"
		&"intelligence":
			return "智力"
		&"constitution":
			return "体质"
		&"speed":
			return "速度"
		&"charm":
			return "魅力"
		&"luck":
			return "幸运"
		_:
			return String(stat_name)
