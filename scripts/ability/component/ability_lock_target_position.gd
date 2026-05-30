## 锁定目标当前位置组件。
## 把 AbilityContext.targets 中的某个 Node2D 目标替换为释放瞬间的坐标，适合落雷、地刺、根须缠绕等“预警后打固定地面”的技能。
class_name AbilityLockTargetPosition
extends AbilityComponent

## 要锁定 targets 中第几个目标。通常配合 AbilityTargetPlayer 使用，默认锁定第一个目标。
@export var target_index: int = 0


func _activate(context: AbilityContext) -> void:
	if context == null:
		return
	if target_index < 0 or target_index >= context.targets.size():
		return

	var target = context.targets[target_index]
	if target is Node2D:
		context.targets[target_index] = (target as Node2D).global_position
