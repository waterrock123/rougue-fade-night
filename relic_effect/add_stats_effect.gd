class_name AddStatEffect
extends RelicEffect


# 通过字典描述要增加的一级属性。
# 支持两种写法：
# 1. {"strength": 3} -> 固定增加 3 点力量
# 2. {"strength": {"value": 0.2, "type": "percent"}} -> 力量提高 20%
@export var add_stats: Dictionary = {}


# 装备生效时，把这件遗物提供的属性加成注册到 StatsController。
func on_activate(relic_context:RelicContext,effect_key) -> void:
	var owner = relic_context.owner
	var relic_controller = relic_context.relic_controller
	
	var stats_controller := _get_stats_controller(owner, relic_controller)
	if stats_controller == null:
		return

	var modifiers := _build_modifiers(effect_key)
	stats_controller.set_effect_modifiers(effect_key, modifiers)


# 卸下装备时，移除这件遗物注册过的属性加成。
func on_deactivate(relic_context:RelicContext,effect_key) -> void:
	var owner = relic_context.owner
	var relic_controller = relic_context.relic_controller
	var stats_controller := _get_stats_controller(owner, relic_controller)
	if stats_controller == null:
		return

	stats_controller.clear_effect_modifiers(effect_key)


# 把配置字典转换成 StatsController 可直接应用的 Modifier 列表。
func _build_modifiers(effect_key: String) -> Array[Modifier]:
	var result: Array[Modifier] = []

	for stat_name in add_stats.keys():
		var modifier := _build_modifier_from_config(StringName(stat_name), add_stats[stat_name], effect_key)
		if modifier != null:
			result.append(modifier)

	return result


# 解析单条属性配置。
# 数字默认视为固定值，字典则允许继续扩展更多配置字段。
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


# 优先从 RelicController 获取绑定好的 StatsController。
# 这样效果层只负责描述“我要加什么”，不关心实体细节。
func _get_stats_controller(owner, relic_controller: RelicController) -> StatsController:
	if relic_controller != null:
		return relic_controller.get_stats_controller()

	if owner is Entity:
		return (owner as Entity).stats_controller

	return null
