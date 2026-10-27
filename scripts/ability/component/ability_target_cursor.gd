## 鼠标位置目标组件。把当前鼠标世界坐标写入 AbilityContext.targets，常用于投射物方向、范围落点、指示器释放位置。
class_name AbilityTargetCursor
extends AbilityComponent

## 零表示不限距离；落点技能可设置为与预览大圆一致的施法半径。
@export var max_range: float = 0.0

#瞄准玩家组件
func _activate(context: AbilityContext):
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var mouse_pos: Vector2 = camera.get_global_mouse_position()
	if max_range > 0.0:
		mouse_pos = context.caster.global_position + (mouse_pos - context.caster.global_position).limit_length(max_range)
	context.targets = [mouse_pos]
	
