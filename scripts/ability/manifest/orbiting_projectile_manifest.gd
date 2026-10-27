## 通用环绕飞行道具：复用飞剑环绕/重复命中间隔，补足高速环绕的线段扫掠命中。
## 贴图、伤害、半径与寿命均在场景配置；默认不智能突刺，不攻击地图物件。
class_name OrbitingProjectileManifest
extends OrbitingSwordManifest

## 超过此距离视为传送或大幅位移，不沿整条迁移路径造成伤害；小于等于0不限制。
@export var maximum_sweep_distance: float = 180.0
## 转过较大角度时拆成短弧线扫掠，低帧率也不只检测一条跨圆心的长弦。
@export_range(0.1, 1.0, 0.05) var maximum_step_angle: float = 0.35
@export_range(1, 32, 1) var maximum_motion_steps: int = 16


func _process_motion(delta: float) -> void:
	if motion_state != MOTION_ORBIT:
		super._process_motion(delta)
		return
	var end_time: float = life_timer
	var steps: int = clampi(ceili(absf(orbit_speed) * delta / maxf(maximum_step_angle, 0.1)), 1, maxi(maximum_motion_steps, 1))
	for index: int in range(steps):
		var previous: Vector2 = global_position
		life_timer = end_time - delta + delta * float(index + 1) / steps
		super._process_motion(delta / steps)
		if is_queued_for_deletion() or _should_free_for_source_state():
			break
		if maximum_sweep_distance > 0.0 and previous.distance_to(global_position) > maximum_sweep_distance:
			continue
		# 重叠与扫掠共享hit_cooldowns，同一帧不会对同一敌人重复结算。
		_apply_swept_dash_damage(previous, global_position)
	life_timer = end_time


func _damage_target(target: Entity, valid_source: Entity) -> void:
	if not is_instance_valid(valid_source) or valid_source.is_dead:
		return
	super._damage_target(target, valid_source)
