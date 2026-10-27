## 锁定施法者的二维战斗朝向；只负责朝向，不移动、不造成伤害。
class_name AbilityLockFacing
extends AbilityComponent

@export var duration: float = 1.0
## 防御型招式保持当前慢速转向结果；冲刺/远程起手可直接锁定目标方向。
@export var use_current_facing: bool = false


func _activate(context: AbilityContext) -> void:
	var direction: Vector2 = context.caster.get_facing_direction() if use_current_facing else context.locked_direction
	if direction == Vector2.ZERO:
		direction = context.caster.get_facing_direction()
	context.locked_direction = direction
	if context.caster.has_method("lock_combat_facing"):
		context.caster.call("lock_combat_facing", direction, duration)
