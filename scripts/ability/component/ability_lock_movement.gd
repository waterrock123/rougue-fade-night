## 施法移动锁定组件。
## 释放技能时让施法者在一段时间内停止自动移动，避免 Boss 播放攻击动画时还在寻路“飘移”。
## 这个组件只负责锁移动，不播放动画、不造成伤害；需要原地施法的技能挂上它即可。
class_name AbilityLockMovement
extends AbilityComponent

@export var lock_duration: float = 0.6


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		return
	if lock_duration <= 0.0:
		return
	if not context.caster.has_method("lock_movement"):
		return

	context.caster.lock_movement(lock_duration)
