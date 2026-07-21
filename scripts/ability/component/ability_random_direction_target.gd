## 随机方向目标组件。
## 释放时给 AbilityContext 写入一个随机方向和目标点，适合狂暴冲撞、失控位移等不依赖鼠标/敌人的技能。
class_name AbilityRandomDirectionTarget
extends AbilityComponent

@export var target_distance: float = 220.0
@export var turn_caster_to_direction: bool = true


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		return

	var direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU).normalized()
	context.locked_direction = direction
	context.targets.clear()
	context.targets.append(context.caster.global_position + direction * max(target_distance, 0.0))

	if turn_caster_to_direction:
		context.caster.turn_to_position(context.caster.global_position + direction)
