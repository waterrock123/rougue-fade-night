class_name StatusAddStatEffect
extends StatusEffect

@export var stat_name: StringName
@export var value_per_stack: float = 1.0
@export var modifier_type: Modifier.ModifierType = Modifier.ModifierType.FLAT


# 状态生效时，把状态转成 StatsController 可识别的 Modifier。
func on_apply(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	var amount := value_per_stack * instance.stacks
	var effect_key: String = _get_effect_key(instance)
	var modifier: Modifier
	if modifier_type == Modifier.ModifierType.PERCENT:
		modifier = Modifier.create_percent(stat_name, amount, effect_key)
	else:
		modifier = Modifier.create_flat(stat_name, amount, effect_key)

	var eligible_stacks: int = instance.get_attribute_gain_stacks()
	var ratio: float = float(eligible_stacks) / float(maxi(instance.stacks, 1))
	if instance.status_data.is_negative():
		ratio = 0.0
	stats_controller.set_temporary_effect_modifiers(
		effect_key, [modifier], ratio, "%d:%s" % [instance.get_instance_id(), effect_key], eligible_stacks > 0
	)


func on_remove(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	# 叠层会先移除再重放效果，保留增量基线，避免每次刷新又转化整份加成。
	stats_controller.clear_effect_modifiers(_get_effect_key(instance), true)


func _get_effect_key(instance: StatusInstance) -> String:
	return instance.get_effect_key(instance.status_data.effects.find(self))


func _get_stats_controller(instance: StatusInstance) -> StatsController:
	if instance == null or not is_instance_valid(instance.controller):
		return null
	return instance.controller.get_stats_controller()
