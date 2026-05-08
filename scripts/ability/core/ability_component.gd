class_name AbilityComponent
extends Node

# 技能组件基类。
# 默认会在 Ability 激活时自动执行；
# 如果某个组件希望由动画关键帧或别的逻辑手动触发，可以关闭 auto_activate。
@export var exec_delay: float = 0.0
@export var auto_activate: bool = true


func activate(context: AbilityContext):
	if exec_delay > 0:
		await get_tree().create_timer(exec_delay, false).timeout

	_activate(context)


func _activate(context: AbilityContext):
	pass
