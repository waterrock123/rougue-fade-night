## 转向鼠标组件。让施法者面向当前鼠标世界坐标，适合玩家主动技能释放前调整朝向。
class_name AbilityTurnToMouse
extends AbilityComponent


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		return

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var mouse_pos: Vector2 = camera.get_global_mouse_position()
	var mouse_direction: Vector2 = context.caster.global_position.direction_to(mouse_pos)
	if mouse_direction != Vector2.ZERO:
		# 翻转只负责视觉朝向，完整二维方向交给技能上下文保存。
		context.locked_direction = mouse_direction.normalized()
	context.caster.turn_to_position(mouse_pos)
	context.caster.turning_cooldown += 0.1
