class_name PassiveAddDerivedStatEffect
extends PassiveSkillEffect

# 通过字典描述要增加的派生属性。
# 1. {"static_damage_reduction": 3} -> 固定增加 3 点固定减伤
# 2. {"crit_chance": {"value": 0.1, "type": "percent"}} -> 暴击率提高 10%
@export var add_derived_stats: Dictionary = {}


func apply(context: SkillContext) -> void:
	var stats_controller := context.stats_controller
	if stats_controller == null:
		return

	stats_controller.set_effect_modifiers(context.effect_key, _build_modifiers(context.effect_key))


func remove(context: SkillContext) -> void:
	var stats_controller := context.stats_controller
	if stats_controller == null:
		return

	stats_controller.clear_effect_modifiers(context.effect_key)


func _build_modifiers(effect_key: Variant) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for stat_name in add_derived_stats.keys():
		var modifier := _build_modifier_from_config(StringName(stat_name), add_derived_stats[stat_name], effect_key)
		if modifier != null:
			result.append(modifier)
	return result


func _build_modifier_from_config(stat_name: StringName, config, effect_key: Variant) -> Modifier:
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
