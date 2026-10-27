## 沿锁定方向物理冲刺；撞墙停止，死亡/控制/硬直取消后不再移动。
## 只负责位移，伤害窗口由独立命中组件配置。
class_name AbilityPhysicsCharge
extends AbilityComponent

@export var distance: float = 180.0
@export var duration: float = 0.35


func _activate(context: AbilityContext) -> void:
	var caster: Entity = context.caster
	var direction: Vector2 = context.locked_direction.normalized()
	if direction == Vector2.ZERO or duration <= 0.0:
		return
	caster.clear_terrain_motion_velocity()
	caster.lock_movement(duration)
	var elapsed: float = 0.0
	while elapsed < duration:
		if not is_inside_tree() or not context.is_caster_action_valid() or not caster.can_act():
			return
		var tree: SceneTree = get_tree()
		await tree.physics_frame
		if not is_inside_tree() or not context.is_caster_action_valid() or not caster.can_act():
			return
		var delta: float = minf(get_physics_process_delta_time(), duration - elapsed)
		var planned: Vector2 = direction * distance * delta / duration
		var actual: Vector2 = caster.move_direct_with_physics(planned, false)
		if actual.length_squared() < planned.length_squared() * 0.04:
			return
		elapsed += delta
