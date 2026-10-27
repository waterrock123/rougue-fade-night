## 指定类型的真实伤害免疫，不使用减伤率模拟；不会阻止冻结等状态本身。
class_name PassiveDamageTypeImmunityEffect
extends PassiveSkillEffect

@export var damage_types: Array[int] = []


func apply(context: SkillContext) -> void:
	if is_instance_valid(context.stats_controller):
		context.stats_controller.set_damage_type_immunity(context.effect_key, damage_types)


func remove(context: SkillContext) -> void:
	if is_instance_valid(context.stats_controller):
		context.stats_controller.clear_damage_type_immunity(context.effect_key)
