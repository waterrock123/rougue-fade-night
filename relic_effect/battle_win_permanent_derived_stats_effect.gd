## 战斗胜利结算时永久提升派生属性。
## 适合“每次战斗胜利后最大法力 +2”这类成长。
class_name BattleWinPermanentDerivedStatsEffect
extends RelicEffect

@export var add_derived_stats: Dictionary = {}

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if add_derived_stats.is_empty():
		return

	active_contexts[str(effect_key)] = relic_context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	var contexts := active_contexts.duplicate()
	active_contexts.clear()
	if EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)

	for context_value in contexts.values():
		_apply_permanent_stats(context_value as RelicContext)


func _apply_permanent_stats(relic_context: RelicContext) -> void:
	var player_build := _get_player_build(relic_context)
	var stats_data := player_build.player_stats if player_build != null else null
	if stats_data == null:
		return

	for stat_name in add_derived_stats.keys():
		_add_derived_stat(stats_data, StringName(stat_name), float(add_derived_stats[stat_name]))

	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.bind_player_build(player_build)
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


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is Entity:
		var stats_controller := (relic_context.owner as Entity).stats_controller
		return stats_controller.player_build if stats_controller != null else null
	return null


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	return null
