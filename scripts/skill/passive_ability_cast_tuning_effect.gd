## 按技能id修改投射物基础伤害、冷却、齐射数量或启用蓄力。
## 修正保存在控制器而非Ability实例中，装备刷新重建技能栏时不会丢失。
class_name PassiveAbilityCastTuningEffect
extends PassiveSkillEffect

@export var target_ability_ids: Array[StringName] = []
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
## 0沿用技能原数量；大于0覆盖齐射组件的基础数量。
@export var projectile_count: int = 0
@export var charge_enabled: bool = false


func apply(context: SkillContext) -> void:
	if not is_instance_valid(context.ability_controller):
		return
	var data: Dictionary = {
		"target_ability_ids": target_ability_ids,
		"damage_multiplier": damage_multiplier,
		"projectile_count": projectile_count,
		"charge_enabled": charge_enabled,
		"cooldown_multiplier": cooldown_multiplier,
	}
	context.ability_controller.set_cast_tuning_modifier(context.effect_key, data)
	context.ability_controller.set_cooldown_modifier(context.effect_key, data)


func remove(context: SkillContext) -> void:
	if not is_instance_valid(context.ability_controller):
		return
	context.ability_controller.clear_cast_tuning_modifier(context.effect_key)
	context.ability_controller.clear_cooldown_modifier(context.effect_key)
