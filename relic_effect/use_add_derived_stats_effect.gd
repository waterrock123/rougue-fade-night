## 消耗品使用时增加派生属性的效果。
## 加成注册到运行时 StatsController，一般用于只持续当前战斗的暴击率、减伤率等临时属性。
class_name UseAddDerivedStatsEffect
extends RelicEffect

@export var add_derived_stats: Dictionary = {}
@export var ignore_when_relic_levelup: bool = false


func on_use(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or add_derived_stats.is_empty():
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	stats_controller.set_effect_modifiers(effect_key, _build_modifiers(effect_key))


func _build_modifiers(effect_key: String) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for stat_name in add_derived_stats.keys():
		var amount := float(add_derived_stats[stat_name])
		result.append(Modifier.create_flat(StringName(stat_name), amount, effect_key))
	return result


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null
