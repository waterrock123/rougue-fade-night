## 锁定附近最近有效目标的方向；只负责瞄准，不负责生成投射物或计算伤害。
## 没有目标时仍可朝鼠标方向空放，适合自动索敌的普攻、飞弹和齐射技能。
class_name AbilityLockNearestTargetDirection
extends AbilityComponent

@export var target_group: StringName = &"enemy"
@export var acquire_radius: float = 600.0
@export var turn_caster: bool = true
var selector: ProjectileHomingController = ProjectileHomingController.new()


func _activate(context: AbilityContext) -> void:
	if context == null or not context.is_caster_action_valid():
		return
	var caster: Entity = context.caster
	var target: Entity = selector.find_nearest_target(caster, caster, target_group, acquire_radius)
	var direction: Vector2 = get_aim_direction(caster, target)
	# 只传方向，清除旧目标列表，避免它覆盖齐射组件为各枚飞弹设置的展开角度。
	context.targets.clear()
	context.locked_direction = direction
	if turn_caster:
		caster.turn_to_position(caster.global_position + direction)


func get_aim_direction(caster: Entity, target: Entity) -> Vector2:
	if is_instance_valid(target):
		var target_direction: Vector2 = caster.global_position.direction_to(target.global_position)
		if not target_direction.is_zero_approx():
			return target_direction
	var mouse_direction: Vector2 = caster.global_position.direction_to(caster.get_global_mouse_position())
	if not mouse_direction.is_zero_approx():
		return mouse_direction
	var facing: Vector2 = caster.get_facing_direction()
	return facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
