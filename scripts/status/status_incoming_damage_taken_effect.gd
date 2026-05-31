## 状态效果：修改目标受到的伤害。
## 典型用法是“易伤”：目标受到的所有最终伤害提高 30%。
class_name StatusIncomingDamageTakenEffect
extends StatusEffect

@export var percent_bonus: float = 0.3
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []


func on_apply(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	stats_controller.set_incoming_damage_taken_modifier(_get_effect_key(instance), {
		"percent_bonus": percent_bonus * instance.stacks,
		"required_tags": required_tags.duplicate(),
		"required_damage_types": required_damage_types.duplicate(),
	})


func on_remove(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	stats_controller.clear_incoming_damage_taken_modifier(_get_effect_key(instance))


func _get_stats_controller(instance: StatusInstance) -> StatsController:
	if instance == null or instance.controller == null:
		return null
	return instance.controller.get_stats_controller()


func _get_effect_key(instance: StatusInstance) -> String:
	return "%s_incoming_damage_taken" % instance.get_effect_key()
