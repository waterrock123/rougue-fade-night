## 优先锁定移动输入方向，没有移动输入则朝鼠标；只负责方向，不造成位移。
class_name AbilityLockMovementDirection
extends AbilityComponent

@export var left_action: StringName = &"leftmove"
@export var right_action: StringName = &"rightmove"
@export var up_action: StringName = &"upmove"
@export var down_action: StringName = &"downmove"


func _activate(context: AbilityContext) -> void:
	var direction: Vector2 = Input.get_vector(left_action, right_action, up_action, down_action)
	if direction.is_zero_approx():
		direction = context.caster.get_global_mouse_position() - context.caster.global_position
	if direction.is_zero_approx():
		direction = context.caster.get_facing_direction()
	context.locked_direction = direction.normalized()
