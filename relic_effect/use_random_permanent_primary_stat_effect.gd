class_name UseRandomPermanentPrimaryStatEffect
extends RelicEffect

const DEFAULT_PRIMARY_STATS: Array[StringName] = [
	&"strength", &"dexterity", &"intelligence", &"constitution",
	&"speed", &"charm", &"luck",
]

## 使用时随机永久提升一项一级属性。
@export var random_primary_stats: Array[StringName] = DEFAULT_PRIMARY_STATS
@export var stat_amount: int = 1


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or random_primary_stats.is_empty() or stat_amount == 0:
		return

	var player_build: PlayerBuild = _get_player_build(relic_context)
	var stats_data: StatsData = player_build.player_stats if player_build != null else _get_runtime_stats_data(relic_context)
	if stats_data == null:
		return

	var stat_name: StringName = random_primary_stats[randi_range(0, random_primary_stats.size() - 1)]
	_add_primary_stat(stats_data, stat_name, stat_amount)
	_resync_stats_controller(relic_context, player_build)
	if EventBus != null:
		EventBus.attribute_update.emit()


func _add_primary_stat(stats_data: StatsData, stat_name: StringName, amount: int) -> void:
	match stat_name:
		&"strength": stats_data.strength += amount
		&"dexterity": stats_data.dexterity += amount
		&"intelligence": stats_data.intelligence += amount
		&"constitution": stats_data.constitution += amount
		&"speed": stats_data.speed += amount
		&"charm": stats_data.charm += amount
		&"luck": stats_data.luck += amount


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner is Entity and (relic_context.owner as Entity).stats_controller != null:
		return (relic_context.owner as Entity).stats_controller.player_build
	return null


func _get_runtime_stats_data(relic_context: RelicContext) -> StatsData:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	return stats_controller.stats_data if stats_controller != null else null


func _resync_stats_controller(relic_context: RelicContext, player_build: PlayerBuild) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null:
		return
	if player_build != null:
		stats_controller.bind_player_build(player_build)
	else:
		stats_controller.recompute_stats()


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	return relic_context.owner.get_node_or_null("StatsController") as StatsController

