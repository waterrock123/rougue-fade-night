## 使用消耗品时立即清除当前技能剩余冷却。不改变技能基础冷却，也不自动释放技能。
class_name UseResetAbilityCooldownsEffect
extends RelicEffect

@export var include_basic_attack: bool = true


func on_use(context: RelicContext, _effect_key: Variant) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var controller: AbilityController = context.owner.get_node_or_null("AbilityController") as AbilityController
	if controller == null:
		return
	for ability: Ability in controller.abilities:
		if not is_instance_valid(ability):
			continue
		if not include_basic_attack and ability.skill_data != null and ability.skill_data.is_basic_attack:
			continue
		controller.reduce_remaining_cooldown(ability, 1.0)
