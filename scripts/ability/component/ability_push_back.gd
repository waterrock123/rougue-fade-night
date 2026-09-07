## 施法者前推组件。让施法者朝面向方向小幅位移，常用于近战挥击、突进起手的手感补偿。
class_name AbilityPushBack
extends AbilityComponent

## 前推距离。
@export var push_back_distance: float = 30.0
## 前推持续时间。
@export var duration: float = 1.0
## 每攻击几次触发一次前推；-1 表示每次都触发。
@export var frequenct: int = 2
## 超过这个毫秒数没有触发时，重置前推计数。
@export var clear_tween: int = 1000
## true 表示朝鼠标方向前推；false 表示朝鼠标反方向后撤。
@export var revert: bool = false
## 开启后使用 CharacterBody2D 碰撞位移，避免贴墙/贴石头时被硬塞进碰撞体。
@export var use_physics_movement: bool = true
## 撞到障碍且实际位移明显不足时提前停止，避免持续往墙里挤。
@export var stop_when_blocked: bool = true
## 实际位移小于计划位移的这个比例时，认为被挡住。
@export_range(0.0, 1.0, 0.05) var blocked_min_movement_ratio: float = 0.2
## 技能位移开始前清空脚下地形惯性，避免冰面滑行速度干扰冲刺/前推。
@export var clear_terrain_inertia_before_push: bool = true

var push_back_counter: int = 0
var last_activation_time: int = -1


func _activate(context: AbilityContext):
	if context == null or context.caster == null:
		return

	if frequenct != -1 and Time.get_ticks_msec() - last_activation_time > max(clear_tween, 0):
		push_back_counter = 0

	push_back_counter += 1
	last_activation_time = Time.get_ticks_msec()
	if frequenct != -1 and push_back_counter < max(frequenct, 1):
		return

	push_back_counter = 0
	var caster: Entity = context.caster
	var push_dir: Vector2 = _get_push_direction(caster)
	if push_dir == Vector2.ZERO:
		return

	if clear_terrain_inertia_before_push and caster.has_method("clear_terrain_motion_velocity"):
		caster.clear_terrain_motion_velocity()

	if use_physics_movement and caster.has_method("move_direct_with_physics"):
		await _move_with_physics(caster, push_dir, context)
	else:
		_move_with_tween(caster, push_dir)


func _get_push_direction(caster: Entity) -> Vector2:
	if caster == null:
		return Vector2.ZERO

	var caster_pos: Vector2 = caster.global_position
	var mouse_pos: Vector2 = caster_pos + caster.get_facing_direction()
	var camera: Camera2D = get_window().get_camera_2d()
	if camera != null:
		mouse_pos = camera.get_global_mouse_position()

	var push_dir: Vector2 = Vector2.ZERO
	if revert:
		push_dir = (mouse_pos - caster_pos).normalized()
	else:
		push_dir = (caster_pos - mouse_pos).normalized()
	return push_dir


func _move_with_physics(caster: Entity, push_dir: Vector2, context: AbilityContext) -> void:
	var safe_duration: float = max(duration, 0.001)
	var elapsed_time: float = 0.0
	while elapsed_time < safe_duration:
		await get_tree().physics_frame

		if context == null or not context.is_caster_action_valid():
			return
		if caster == null or not is_instance_valid(caster) or caster.is_dead:
			return

		var frame_delta: float = min(get_physics_process_delta_time(), safe_duration - elapsed_time)
		if frame_delta <= 0.0:
			continue

		var planned_delta: Vector2 = push_dir * push_back_distance * (frame_delta / safe_duration)
		var actual_delta: Vector2 = caster.move_direct_with_physics(planned_delta, false)
		if stop_when_blocked and _is_blocked(planned_delta, actual_delta):
			return

		elapsed_time += frame_delta


func _is_blocked(planned_delta: Vector2, actual_delta: Vector2) -> bool:
	if planned_delta.length_squared() <= 0.000001:
		return false
	return actual_delta.length() < planned_delta.length() * blocked_min_movement_ratio


func _move_with_tween(caster: Entity, push_dir: Vector2) -> void:
	var target_pos: Vector2 = caster.global_position + push_dir * push_back_distance
	var tween: Tween = create_tween()
	tween.tween_property(caster, "global_position", target_pos, max(duration, 0.001))
	tween.set_ease(Tween.EASE_IN)
