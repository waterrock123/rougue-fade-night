## 消耗品使用时永久提升派生属性。
## 它直接写入 PlayerBuild.player_stats 的 base_* 字段，适合永久暴击率、永久减伤率等成长。
class_name UsePermanentDerivedStatsEffect
extends RelicEffect

@export var add_derived_stats: Dictionary = {}


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or add_derived_stats.is_empty():
		return

	var player_build := _get_player_build(relic_context)
	var stats_data := player_build.player_stats if player_build != null else _get_runtime_stats_data(relic_context)
	if stats_data == null:
		return

	for stat_name in add_derived_stats.keys():
		_add_derived_stat(stats_data, StringName(stat_name), float(add_derived_stats[stat_name]))

	_resync_stats_controller(relic_context, player_build)
	EventBus.attribute_update.emit()


func _add_derived_stat(stats_data: StatsData, stat_name: StringName, amount: float) -> void:
	match stat_name:
		&"max_health":
			stats_data.base_max_health += amount
		&"max_energy":
			stats_data.base_max_energy += amount
		&"move_speed":
			stats_data.base_move_speed += amount
		&"crit_chance":
			stats_data.base_crit_chance += amount
		&"crit_damage":
			stats_data.base_crit_damage += amount
		&"damage_reduction_rate":
			stats_data.base_damage_reduction_rate += amount
		&"static_damage_reduction":
			stats_data.base_static_damage_reduction += int(amount)
		&"dodge_rate":
			stats_data.base_dodge_rate += amount
		&"cooldown_reduction":
			stats_data.base_cooldown_reduction += amount
		&"energy_regen_tick_value":
			stats_data.base_energy_regen_tick_value += amount


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
