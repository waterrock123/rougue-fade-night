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
	var effect_key := instance.get_effect_key()
	var modifier: Modifier
	if modifier_type == Modifier.ModifierType.PERCENT:
		modifier = Modifier.create_percent(stat_name, amount, effect_key)
	else:
		modifier = Modifier.create_flat(stat_name, amount, effect_key)

	stats_controller.set_effect_modifiers(effect_key, [modifier])


func on_remove(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	stats_controller.clear_effect_modifiers(instance.get_effect_key())


func _get_stats_controller(instance: StatusInstance) -> StatsController:
	if instance == null or instance.controller == null:
		return null
	return instance.controller.get_stats_controller()
