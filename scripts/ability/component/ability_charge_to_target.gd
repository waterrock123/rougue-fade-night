## 冲锋位移组件。让施法者朝 AbilityContext 中的目标或默认敌对目标冲刺一段距离；只负责位移，不负责伤害。
class_name AbilityChargeToTarget
extends AbilityComponent

# 冲锋位移组件。
# 作用是让施法者朝目标方向冲一段距离：
# 1. 优先使用前置组件写入到 context.targets 的目标；
# 2. 如果前面没有提供目标，就自动寻找默认敌对目标；
# 3. 这个组件只负责位移，不负责造成伤害。

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
	if caster.has_method("register_action_tween"):
		caster.register_action_tween(tween)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(caster, "position", end_pos, duration)


# 优先读取前置组件已经选好的目标位置。
func _resolve_target_position(context: AbilityContext):
	if context.targets.size() > 0:
		var first_target = context.targets[0]
		if first_target is Entity:
			return (first_target as Entity).global_position
		if first_target is Vector2:
			return first_target

	return _find_default_target_position(context.caster)


# 如果没有前置目标，就自动找一个默认敌对目标。
func _find_default_target_position(caster: Entity):
	if caster == null or caster.get_tree() == null:
		return null

	var target := _find_nearest_opponent(caster)
	if target != null:
		return target.global_position

	return null


func _find_nearest_opponent(caster: Entity) -> Entity:
	var nearest: Entity
	var nearest_distance := INF
	var groups: Array[StringName] = _get_opponent_groups(caster)

	for group_name in groups:
		for node in caster.get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var candidate := node as Entity
			if caster.is_enemy_side() and not candidate.is_player_side():
				continue
			if caster.is_player_side() and not candidate.is_enemy_side():
				continue
			if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
				continue

			var distance := caster.global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate

	return nearest


func _get_opponent_groups(caster: Entity) -> Array[StringName]:
	var groups: Array[StringName] = []
	if caster.is_enemy_side():
		groups.append(&"player")
		groups.append(&"player_ally")
		groups.append(&"summon_pet")
	else:
		groups.append(&"enemy")
	return groups
