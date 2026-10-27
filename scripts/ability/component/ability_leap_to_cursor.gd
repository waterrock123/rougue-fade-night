## 限距跃进：复用安全落点解析，实体沿地面物理移动，仅视觉节点呈抛物线升降。
## 不提供无敌、不翻越墙体；落地后执行子组件，控制、死亡和退场则取消并还原偏移。
class_name AbilityLeapToCursor
extends AbilityTeleportToCursor

@export var leap_seconds: float = 0.4
@export var visual_height: float = 32.0
@export var visual_paths: Array[NodePath] = [NodePath("AnimatedSprite2D"), NodePath("Weapon")]
var active_context: AbilityContext
var elapsed: float = 0.0
var start_position: Vector2
var landing_position: Vector2
var visual_offset: float = 0.0
var visuals: Array[Node2D] = []
var controller: AbilityController
var lock_key: String


func can_pay_ability_cost(_context: AbilityContext) -> bool:
	return active_context == null


func _activate(context: AbilityContext) -> void:
	_finish(false)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null or not EventBus.is_battle_active:
		return
	active_context = context
	elapsed = 0.0
	start_position = context.caster.global_position
	var map: Node = get_tree().get_first_node_in_group("battle_map")
	landing_position = resolve_destination(context.caster, map, camera.get_global_mouse_position())
	lock_key = "leap_%d" % get_instance_id()
	context.caster.add_movement_lock(lock_key)
	controller = context.caster.get_node_or_null("AbilityController") as AbilityController
	if is_instance_valid(controller):
		controller.set_cast_block_modifier(lock_key, {"block_all": true})
	for path: NodePath in visual_paths:
		var visual: Node2D = context.caster.get_node_or_null(path) as Node2D
		if visual != null and not visuals.has(visual):
			visuals.append(visual)


func _physics_process(delta: float) -> void:
	if active_context == null:
		return
	if not _can_continue():
		_finish(false)
		return
	var duration: float = maxf(leap_seconds, 0.001)
	elapsed = minf(elapsed + maxf(delta, 0.0), duration)
	var progress: float = elapsed / duration
	var caster: Entity = active_context.caster
	var planned: Vector2 = start_position.lerp(landing_position, progress) - caster.global_position
	var map: Node = get_tree().get_first_node_in_group("battle_map")
	if not _is_safe(caster, map, caster.global_position, caster.global_position + planned):
		_finish(true)
		return
	var actual: Vector2 = caster.move_direct_with_physics(planned, false)
	_set_visual_offset(-sin(progress * PI) * maxf(visual_height, 0.0))
	if progress >= 1.0 or (not planned.is_zero_approx() and actual.length_squared() < planned.length_squared() * 0.04):
		_finish(true)


func _can_continue() -> bool:
	return EventBus.is_battle_active and active_context.is_caster_action_valid() and active_context.caster.can_act()


func _set_visual_offset(value: float) -> void:
	for visual: Node2D in visuals:
		if is_instance_valid(visual):
			visual.position.y += value - visual_offset
	visual_offset = value


func _finish(completed: bool) -> void:
	var context: AbilityContext = active_context
	_set_visual_offset(0.0)
	visuals.clear()
	active_context = null
	if is_instance_valid(controller):
		controller.clear_cast_block_modifier(lock_key)
	controller = null
	if context == null or not is_instance_valid(context.caster):
		return
	context.caster.remove_movement_lock(lock_key)
	context.caster.clear_terrain_motion_velocity()
	if not completed or not EventBus.is_battle_active or not context.is_caster_action_valid() or not context.caster.can_act():
		return
	for child: Node in get_children():
		if not context.is_caster_action_valid():
			break
		if child is AbilityComponent and child.auto_activate:
			child.activate(context)


func _exit_tree() -> void:
	_finish(false)
