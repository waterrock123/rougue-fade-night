## 获得遗物时永久增加一级属性的通用效果。
## 数值直接写入 PlayerBuild.player_stats，因此会跨战斗保留。
class_name GainPermanentStatsEffect
extends RelicEffect

## 示例：{"dexterity": 1, "luck": 2}。
@export var add_stats: Dictionary = {}


func on_gain(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or add_stats.is_empty():
		return

	var player_build: PlayerBuild = _resolve_player_build(relic_context)
	if player_build == null or player_build.player_stats == null:
		return

	for stat_name: Variant in add_stats.keys():
		_add_primary_stat(player_build.player_stats, StringName(stat_name), int(add_stats[stat_name]))

	var stats_controller: StatsController = _resolve_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.bind_player_build(player_build)
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


func _resolve_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner is Entity:
		var stats_controller: StatsController = (relic_context.owner as Entity).stats_controller
		if stats_controller != null and stats_controller.player_build != null:
			return stats_controller.player_build

	var current_node: Node = relic_context.owner
	while current_node != null:
		var run_stats_value: Variant = current_node.get("run_stats")
		if run_stats_value is RunStats:
			return (run_stats_value as RunStats).player_build
		current_node = current_node.get_parent()
	return null


func _resolve_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null
