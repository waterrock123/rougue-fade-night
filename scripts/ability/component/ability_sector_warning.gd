## 显示已锁定方向的扇形预警；半径、角度须与取目标组件一致。
class_name AbilitySectorWarning
extends AbilityComponent

@export var radius: float = 130.0
@export var angle_degrees: float = 110.0
@export var duration: float = 0.8


func _activate(context: AbilityContext) -> void:
	var warning: EncounterWarning = EncounterWarning.spawn(context, context.caster.global_position, radius, duration)
	warning.shape = EncounterWarning.Shape.SECTOR
	warning.angle_degrees = angle_degrees
	warning.global_rotation = context.locked_direction.angle()
