## 消耗品使用时增加一级属性的效果。
## 加成注册到运行时 StatsController，一般用于只在当前战斗内生效的临时属性。
class_name UseAddStatsEffect
extends RelicEffect


## 使用后增加的一级属性字典，示例：{"strength": 2, "speed": 1}。
@export var add_stats: Dictionary = {}
## 勾选后，升级态遗物会跳过这条基础临时属性效果。
## 适合“升级后临时属性改为永久属性”的消耗品，避免基础效果和升级效果重复生效。
@export var ignore_when_relic_levelup: bool = false


## 使用消耗品时添加本场运行时属性修饰。
## 这里只注册 Modifier，不直接修改 StatsData，因此战斗结束重新绑定构筑数据后会自然失效。
func on_use(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or add_stats.is_empty():
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	var modifiers: Array[Modifier] = []
	for stat_name in add_stats.keys():
		var amount := float(add_stats[stat_name])
		modifiers.append(Modifier.create_flat(StringName(stat_name), amount, String(effect_key)))

	stats_controller.set_effect_modifiers(effect_key, modifiers)


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	return relic_context.owner.get_node_or_null("StatsController") as StatsController
