class_name AbilityKnockbackTargets
extends AbilityComponent

@export var distance: float = 90.0
@export var duration: float = 0.16
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var transition_type: Tween.TransitionType = Tween.TRANS_QUAD


func _activate(context: AbilityContext):
	if context == null or context.caster == null:
		return

	for target_data in context.targets:
		var target := _resolve_target(target_data)
		if target == null or target == context.caster:
			continue

		_knockback_target(context.caster, target)


func _resolve_target(target_data) -> Entity:
	if target_data is Entity:
		return target_data as Entity
	return null


func _knockback_target(caster: Entity, target: Entity) -> void:
	var direction := caster.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		direction = caster.get_facing_direction()

	# 这里直接推动目标位置，后续如果需要墙体阻挡，可以再升级成 move_and_collide 版本。
	var target_position := target.global_position + direction.normalized() * distance
	var tween := create_tween()
	tween.tween_property(target, "global_position", target_position, duration)
	tween.set_ease(ease_type)
	tween.set_trans(transition_type)
