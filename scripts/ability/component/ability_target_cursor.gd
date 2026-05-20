## 鼠标位置目标组件。把当前鼠标世界坐标写入 AbilityContext.targets，常用于投射物方向、范围落点、指示器释放位置。
class_name AbilityTargetCursor
extends AbilityComponent

#瞄准玩家组件
func _activate(context: AbilityContext):
	var mouse_pos = get_window().get_camera_2d().get_global_mouse_position()
	context.targets = [mouse_pos]
	
