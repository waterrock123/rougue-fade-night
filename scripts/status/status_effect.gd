class_name StatusEffect
extends Resource


# 状态被添加或刷新时调用。子类在这里注册属性修饰、初始化计时等。
func on_apply(_instance: StatusInstance) -> void:
	pass


# 状态每帧推进时调用。持续伤害、持续回血这类效果会用到。
func on_tick(_instance: StatusInstance, _delta: float) -> void:
	pass


# 状态结束或被移除时调用。子类在这里清理注册过的效果。
func on_remove(_instance: StatusInstance) -> void:
	pass
