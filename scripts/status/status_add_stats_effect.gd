class_name StatusAddStatsEffect
extends StatusEffect

## 一个状态一次性提供多项属性修饰。
## 相比多个 StatusAddStatEffect，这个脚本会把所有 modifier 放在同一个来源 key 下，避免互相覆盖。
@export var stat_values: Dictionary = {}
@export var modifier_type: Modifier.ModifierType = Modifier.ModifierType.FLAT


## 状态生效或刷新时，把当前层数折算成一组属性修饰。
func on_apply(instance: StatusInstance) -> void:
	var stats_controller: StatsController = _get_stats_controller(instance)
	if stats_controller == null:
		return

	var effect_key: String = _get_effect_key(instance)
	var modifiers: Array[Modifier] = []
	for stat_key in stat_values.keys():
		var stat_name: StringName = StringName(str(stat_key))
		var amount: float = float(stat_values[stat_key]) * float(instance.stacks)
		var modifier: Modifier
		if modifier_type == Modifier.ModifierType.PERCENT:
			modifier = Modifier.create_percent(stat_name, amount, effect_key)
		else:
			modifier = Modifier.create_flat(stat_name, amount, effect_key)
		modifiers.append(modifier)

	var eligible_stacks: int = instance.get_attribute_gain_stacks()
	var ratio: float = float(eligible_stacks) / float(maxi(instance.stacks, 1))
	if instance.status_data.is_negative():
		ratio = 0.0
	stats_controller.set_temporary_effect_modifiers(
		effect_key, modifiers, ratio, "%d:%s" % [instance.get_instance_id(), effect_key], eligible_stacks > 0
	)


## 状态结束或被移除时，清理这一组属性修饰。
func on_remove(instance: StatusInstance) -> void:
	var stats_controller: StatsController = _get_stats_controller(instance)
	if stats_controller == null:
		return

	stats_controller.clear_effect_modifiers(_get_effect_key(instance), true)


func _get_effect_key(instance: StatusInstance) -> String:
	return instance.get_effect_key(instance.status_data.effects.find(self))


func _get_stats_controller(instance: StatusInstance) -> StatsController:
	if instance == null or not is_instance_valid(instance.controller):
		return null
	return instance.controller.get_stats_controller()
