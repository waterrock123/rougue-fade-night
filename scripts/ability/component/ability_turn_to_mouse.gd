## 转向鼠标组件。让施法者面向当前鼠标世界坐标，适合玩家主动技能释放前调整朝向。
class_name AbilityTurnToMouse
extends AbilityComponent


func _activate(context: AbilityContext):
	var mouse_pos = get_window().get_camera_2d().get_global_mouse_position()
	context.caster.turn_to_position(mouse_pos)
	context.caster.turning_cooldown +=0.1
