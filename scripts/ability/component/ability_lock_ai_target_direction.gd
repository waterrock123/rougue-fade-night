## 把AI当前追击目标的方向锁进技能上下文，延迟攻击期间不重新转向；兼容敌人与召唤物。
class_name AbilityLockAiTargetDirection
extends AbilityComponent


func _activate(context: AbilityContext) -> void:
	var target: Entity
	if context.caster is Enemy:
		target = (context.caster as Enemy).current_target
	elif context.caster is SummonPet:
		target = (context.caster as SummonPet).target
	context.locked_direction = context.caster.global_position.direction_to(target.global_position) if is_instance_valid(target) else context.caster.get_facing_direction()
