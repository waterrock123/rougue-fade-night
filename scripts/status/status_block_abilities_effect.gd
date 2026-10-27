## 只禁止基础攻击或指定主动技能，不影响移动和其余主动技能。
## 随状态施加/移除登记独立来源，多个限制状态不会互相误删。
class_name StatusBlockAbilitiesEffect
extends StatusEffect

@export var block_basic_attack: bool = true
@export var ability_ids: Array[StringName] = []


func on_apply(instance: StatusInstance) -> void:
	var controller: AbilityController = _get_controller(instance)
	if controller != null:
		controller.set_cast_block_modifier(instance.get_effect_key(), {
			"block_basic_attack": block_basic_attack,
			"ability_ids": ability_ids,
		})


func on_remove(instance: StatusInstance) -> void:
	var controller: AbilityController = _get_controller(instance)
	if controller != null:
		controller.clear_cast_block_modifier(instance.get_effect_key())


func _get_controller(instance: StatusInstance) -> AbilityController:
	if instance == null or not is_instance_valid(instance.target):
		return null
	return instance.target.get_node_or_null("AbilityController") as AbilityController
