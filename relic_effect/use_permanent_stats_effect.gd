## 消耗品使用时永久提升一级属性的通用效果。
## 它会写入 PlayerBuild.player_stats，而不是只注册运行时 Modifier，因此可跨战斗保留。
class_name UsePermanentStatsEffect
extends RelicEffect

## 永久增加的一级属性字典，例如 {"constitution": 2}。
@export var add_stats: Dictionary = {}


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or add_stats.is_empty():
		return

	var player_build := _get_player_build(relic_context)
	var stats_data := player_build.player_stats if player_build != null else _get_runtime_stats_data(relic_context)
	if stats_data == null:
		return

	for stat_name in add_stats.keys():
		_add_primary_stat(stats_data, StringName(stat_name), int(add_stats[stat_name]))

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


func _resync_stats_controller(relic_context: RelicContext, player_build: PlayerBuild) -> void:
	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	if player_build != null:
		stats_controller.bind_player_build(player_build)
	else:
		stats_controller.recompute_stats()


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner is Entity:
		var stats_controller := (relic_context.owner as Entity).stats_controller
		if stats_controller != null:
			return stats_controller.player_build
	return null


func _get_runtime_stats_data(relic_context: RelicContext) -> StatsData:
	var stats_controller := _get_stats_controller(relic_context)
	return stats_controller.stats_data if stats_controller != null else null


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null
