## 技能组件基类。挂在 Ability 节点下，用于把一个技能拆成“取目标、播放动画、造成伤害、生成投射物”等小步骤。
## 默认会随 Ability 释放自动执行；如果希望由动画关键帧等机制手动触发，可以关闭 auto_activate。
class_name AbilityComponent
extends Node

@export var exec_delay: float = 0.0
@export var auto_activate: bool = true


func activate(context: AbilityContext):
	if context == null or not context.is_caster_action_valid():
		return
	if exec_delay > 0:
		await get_tree().create_timer(exec_delay, false).timeout
	if context == null or not context.is_caster_action_valid():
		return

	_activate(context)


func _activate(context: AbilityContext):
	pass
