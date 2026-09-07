## 增加派生属性的遗物效果。
## 适合用于固定减伤、减伤率、暴击率、闪避率、冷却缩减、削韧倍率等派生属性。
class_name AddDerivedStatEffect
extends RelicEffect


## 要增加的派生属性字典。
## 示例：{"static_damage_reduction": 1} 或 {"damage_reduction_rate": {"value": 0.1, "type": "flat"}}。
@export var add_derived_stats: Dictionary = {}


## 装备生效时，把派生属性修饰注册到 StatsController。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner = relic_context.owner
	var relic_controller = relic_context.relic_controller
	var stats_controller := _get_stats_controller(owner, relic_controller)
	if stats_controller == null:
		return

	var modifiers := _build_modifiers(effect_key)
	stats_controller.set_effect_modifiers(effect_key, modifiers)


## 卸下装备时，移除这件遗物提供的派生属性修饰。
func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var owner = relic_context.owner
	var relic_controller = relic_context.relic_controller
	var stats_controller := _get_stats_controller(owner, relic_controller)
	if stats_controller == null:
		return

	stats_controller.clear_effect_modifiers(effect_key)


## 把配置字典转换成 Modifier 列表。
func _build_modifiers(effect_key: String) -> Array[Modifier]:
	var result: Array[Modifier] = []

	for stat_name in add_derived_stats.keys():
		var modifier := _build_modifier_from_config(StringName(stat_name), add_derived_stats[stat_name], effect_key)
		if modifier != null:
			result.append(modifier)

	return result


## 解析单条派生属性配置。
func _build_modifier_from_config(stat_name: StringName, config, effect_key: String) -> Modifier:
	if config is float or config is int:
		return Modifier.create_flat(stat_name, float(config), effect_key)

	if config is Dictionary:
		var modifier_config := config as Dictionary
		var value := float(modifier_config.get("value", 0.0))
		var type_name := String(modifier_config.get("type", "flat")).to_lower()
		var duration := float(modifier_config.get("duration", -1.0))

		if type_name == "percent":
			return Modifier.create_percent(stat_name, value, effect_key, duration)

		return Modifier.create_flat(stat_name, value, effect_key, duration)

	return null


## 优先从 RelicController 获取绑定好的 StatsController。
func _get_stats_controller(owner, relic_controller: RelicController) -> StatsController:
	if relic_controller != null:
		return relic_controller.get_stats_controller()

	if owner is Entity:
		return (owner as Entity).stats_controller

	return null
