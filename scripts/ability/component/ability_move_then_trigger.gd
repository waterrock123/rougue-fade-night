## 物理滑步完成后执行子组件；撞墙提前完成，死亡、控制和战斗结束则取消后续动作。
## 使用处理循环与按来源加锁，避免异步协程在切场景后继续位移或开枪。
class_name AbilityMoveThenTrigger
extends AbilityComponent

@export var distance: float = 90.0
@export var duration: float = 0.2
@export var block_other_abilities: bool = true
var active_context: AbilityContext
var elapsed: float = 0.0
var lock_key: String
var controller: AbilityController


func can_pay_ability_cost(_context: AbilityContext) -> bool:
	return active_context == null


func _activate(context: AbilityContext) -> void:
	_finish(false)
	active_context = context
	elapsed = 0.0
	lock_key = "move_then_%d" % get_instance_id()
	context.caster.clear_terrain_motion_velocity()
	context.caster.add_movement_lock(lock_key)
	controller = context.caster.get_node_or_null("AbilityController") as AbilityController
	if block_other_abilities and is_instance_valid(controller):
		controller.set_cast_block_modifier(lock_key, {"block_all": true})
	if duration <= 0.0:
		_finish(true)


func _physics_process(delta: float) -> void:
	if active_context == null:
		return
	if not EventBus.is_battle_active or not active_context.is_caster_action_valid():
		_finish(false)
		return
	var caster: Entity = active_context.caster
	if not caster.can_act():
		_finish(false)
		return
	var step: float = minf(delta, maxf(duration - elapsed, 0.0))
	var planned: Vector2 = active_context.locked_direction * distance * step / maxf(duration, 0.001)
	var actual: Vector2 = caster.move_direct_with_physics(planned, false)
	elapsed += step
	if elapsed >= duration or actual.length_squared() < planned.length_squared() * 0.04:
		_finish(true)


func _finish(completed: bool) -> void:
	var context: AbilityContext = active_context
	active_context = null
	if is_instance_valid(controller):
		controller.clear_cast_block_modifier(lock_key)
	controller = null
	if context == null or not is_instance_valid(context.caster):
		return
	context.caster.remove_movement_lock(lock_key)
	if not completed or not context.is_caster_action_valid() or not context.caster.can_act():
		return
	for child: Node in get_children():
		if child is AbilityComponent and child.auto_activate:
			child.activate(context)


func _exit_tree() -> void:
	_finish(false)
