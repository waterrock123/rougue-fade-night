class_name AbilityChargeToTarget
extends AbilityComponent

# Charge movement settings.
@export var charge_distance: float = 100.0
@export var duration: float = 0.2
@export var hit_width: float = 48.0
@export var stop_at_target: bool = true

func _activate(context: AbilityContext):
	var caster := context.caster
	if caster == null:
		return

	var target_pos_data = _resolve_target_position(context)
	if target_pos_data == null:
		return

	var start_pos := caster.global_position
	var target_pos: Vector2 = target_pos_data
	var charge_dir := (target_pos - start_pos).normalized()
	if charge_dir == Vector2.ZERO:
		charge_dir = caster.get_facing_direction()
	if charge_dir == Vector2.ZERO:
		return

	var actual_distance := charge_distance
	if stop_at_target:
		actual_distance = min(charge_distance, start_pos.distance_to(target_pos))

	if actual_distance <= 0.0:
		return

	if caster.has_method("lock_movement"):
		caster.lock_movement(duration)

	var end_pos := caster.position + charge_dir * actual_distance
	var tween := caster.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(caster, "position", end_pos, duration)


# Prefer the target found by previous components.
func _resolve_target_position(context: AbilityContext):
	if context.targets.size() > 0:
		var first_target = context.targets[0]
		if first_target is Entity:
			return (first_target as Entity).global_position
		if first_target is Vector2:
			return first_target

	return _find_default_target_position(context.caster)


func _find_default_target_position(caster: Entity):
	if caster == null or caster.get_tree() == null:
		return null

	var target_group := "player"
	if caster.is_in_group("player"):
		target_group = "enemy"

	var target = caster.get_tree().get_first_node_in_group(target_group)
	if target is Entity:
		return (target as Entity).global_position

	return null
