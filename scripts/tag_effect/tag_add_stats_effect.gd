## Tag 套装效果：激活时提供一组一级/派生属性修饰。
## 适合“珠光宝气：饰品达到 3 件时，魅力 +7”这类持续型效果。
class_name TagAddStatsEffect
extends TagEffect

@export var add_stats: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	if context == null or context.stats_controller == null:
		return

	var modifiers := _build_modifiers(context.effect_key)
	context.stats_controller.set_effect_modifiers(context.effect_key, modifiers)


func on_deactivate(context: TagEffectContext) -> void:
	if context == null or context.stats_controller == null:
		return

	context.stats_controller.clear_effect_modifiers(context.effect_key)


func _build_modifiers(effect_key: String) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for stat_name in add_stats.keys():
		var modifier := _build_modifier_from_config(StringName(stat_name), add_stats[stat_name], effect_key)
		if modifier != null:
			result.append(modifier)
	return result


func _build_modifier_from_config(stat_name: StringName, config, effect_key: String) -> Modifier:
	if config is float or config is int:
		return Modifier.create_flat(stat_name, float(config), effect_key)

	if config is Dictionary:
		var modifier_config := config as Dictionary
		var value := float(modifier_config.get("value", 0.0))
		var type_name := String(modifier_config.get("type", "flat")).to_lower()
		if type_name == "percent":
			return Modifier.create_percent(stat_name, value, effect_key)
		return Modifier.create_flat(stat_name, value, effect_key)

	return null
