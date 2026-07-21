class_name ConsumableUsedRandomPermanentStatEffect
extends RelicEffect

## 监听战斗中的消耗品使用，并永久提升随机一级属性。
## 当前用于“玉箸”：每场战斗最多触发若干次，升级态第一次使用会额外触发一次。

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
@export var stat_amount: int = 1
@export var max_triggers_per_battle: int = 5
@export var levelup_first_use_extra_triggers: int = 1

var active_records: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if random_primary_stats.is_empty() or stat_amount == 0:
		return

	var key: String = str(effect_key)
	active_records[key] = {
		"context": relic_context,
		"normal_trigger_count": 0,
		"has_used_consumable": false,
	}

	if not EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.connect(_on_consumable_used)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_records.erase(str(effect_key))
	if active_records.is_empty() and EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.disconnect(_on_consumable_used)


func _on_consumable_used(_relic: Relic, user: Entity) -> void:
	if user == null or random_primary_stats.is_empty():
		return

	for key_variant in active_records.keys():
		var key: String = str(key_variant)
		var record: Dictionary = active_records[key] as Dictionary
		var relic_context: RelicContext = record.get("context") as RelicContext
		if relic_context == null or relic_context.owner != user:
			continue

		var grant_count: int = _get_grant_count(record, relic_context)
		if grant_count <= 0:
			continue

		record["has_used_consumable"] = true
		record["normal_trigger_count"] = int(record.get("normal_trigger_count", 0)) + 1
		active_records[key] = record
		_grant_random_permanent_stats(relic_context, grant_count)


func _get_grant_count(record: Dictionary, relic_context: RelicContext) -> int:
	var normal_count: int = int(record.get("normal_trigger_count", 0))
	if normal_count >= max(max_triggers_per_battle, 0):
		return 0

	var grant_count: int = 1
	if not bool(record.get("has_used_consumable", false)) and _is_levelup_relic(relic_context):
		grant_count += max(levelup_first_use_extra_triggers, 0)
	return grant_count


func _grant_random_permanent_stats(relic_context: RelicContext, grant_count: int) -> void:
	var player_build: PlayerBuild = _get_player_build(relic_context)
	var stats_data: StatsData = player_build.player_stats if player_build != null else _get_runtime_stats_data(relic_context)
	if stats_data == null:
		return

	for _index in range(max(grant_count, 0)):
		var stat_name: StringName = _pick_random_stat()
		_add_primary_stat(stats_data, stat_name, stat_amount)

	_resync_stats_controller(relic_context, player_build)
	EventBus.attribute_update.emit()


func _add_primary_stat(stats_data: StatsData, stat_name: StringName, amount: int) -> void:
	match stat_name:
		&"strength":
			stats_data.strength += amount
		&"dexterity":
			stats_data.dexterity += amount
		&"intelligence":
			stats_data.intelligence += amount
		&"constitution":
			stats_data.constitution += amount
		&"speed":
			stats_data.speed += amount
		&"charm":
			stats_data.charm += amount
		&"luck":
			stats_data.luck += amount


func _pick_random_stat() -> StringName:
	var index: int = randi_range(0, random_primary_stats.size() - 1)
	return random_primary_stats[index]


func _is_levelup_relic(relic_context: RelicContext) -> bool:
	return relic_context != null and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP


func _resync_stats_controller(relic_context: RelicContext, player_build: PlayerBuild) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	if player_build != null:
		stats_controller.bind_player_build(player_build)
	else:
		stats_controller.recompute_stats()


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner is Entity:
		var stats_controller: StatsController = (relic_context.owner as Entity).stats_controller
		if stats_controller != null:
			return stats_controller.player_build
	return null


func _get_runtime_stats_data(relic_context: RelicContext) -> StatsData:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	return stats_controller.stats_data if stats_controller != null else null


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null
