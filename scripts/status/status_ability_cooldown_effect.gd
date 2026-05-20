## 状态效果：临时修改指定技能的冷却。适合暴怒、加速施法、沉默/迟缓等状态。
class_name StatusAbilityCooldownEffect
extends StatusEffect

@export var target_ability_ids: Array[StringName] = []
@export var target_slot_indices: Array[int] = []
@export_range(0.0, 10.0, 0.01) var cooldown_multiplier: float = 1.0
@export var flat_reduction: float = 0.0


# 状态生效时，把冷却修正注册到 AbilityController。
func on_apply(instance: StatusInstance) -> void:
	var ability_controller := _get_ability_controller(instance)
	if ability_controller == null:
		return

	ability_controller.set_cooldown_modifier(_get_effect_key(instance), {
		"target_ability_ids": target_ability_ids.duplicate(),
		"target_slot_indices": target_slot_indices.duplicate(),
		"cooldown_multiplier": cooldown_multiplier,
		"flat_reduction": flat_reduction,
	})


# 状态结束时，移除对应的冷却修正。
func on_remove(instance: StatusInstance) -> void:
	var ability_controller := _get_ability_controller(instance)
	if ability_controller == null:
		return

	ability_controller.clear_cooldown_modifier(_get_effect_key(instance))


func _get_ability_controller(instance: StatusInstance) -> AbilityController:
	if instance == null or instance.target == null:
		return null
	return instance.target.get_node_or_null("AbilityController") as AbilityController


func _get_effect_key(instance: StatusInstance) -> String:
	return "%s_cooldown" % instance.get_effect_key()
