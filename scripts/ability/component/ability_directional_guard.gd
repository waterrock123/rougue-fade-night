## 固定施法方向的短暂防御；扣血前降低正面攻击伤害，精准格挡只排队一次反击。
## 反击在下一处理帧执行子组件，避免物理查询回调内生成节点或递归修改当前伤害。
class_name AbilityDirectionalGuard
extends AbilityComponent

@export var guard_seconds: float = 0.8
@export var perfect_seconds: float = 0.25
@export_range(1.0, 360.0) var front_angle: float = 180.0
@export_range(0.0, 1.0) var damage_reduction: float = 0.6
@export_range(0.0, 1.0) var perfect_reduction: float = 0.9
@export_range(0.0, 1.0) var movement_penalty: float = 0.5
@export var perfect_energy_refund: float = 5.0
@export var guard_status: StatusData
var active_context: AbilityContext
var elapsed: float = 0.0
var counter_pending: bool = false
var lock_key: String
var controller: AbilityController
var visual: DirectionalGuardVisual


func can_pay_ability_cost(_context: AbilityContext) -> bool:
	return active_context == null


func _activate(context: AbilityContext) -> void:
	_finish(false)
	if not EventBus.is_battle_active:
		return
	active_context = context
	elapsed = 0.0
	counter_pending = false
	lock_key = "directional_guard_%d" % get_instance_id()
	if context.locked_direction.is_zero_approx():
		context.locked_direction = context.caster.get_facing_direction()
	context.caster.damage_receive_prepared.connect(_on_incoming)
	controller = context.caster.get_node_or_null("AbilityController") as AbilityController
	if is_instance_valid(controller):
		controller.set_cast_block_modifier(lock_key, {"block_all": true})
	if is_instance_valid(context.caster.stats_controller):
		var modifiers: Array[Modifier] = [Modifier.create_percent(&"move_speed", -movement_penalty, lock_key)]
		context.caster.stats_controller.set_effect_modifiers(lock_key, modifiers)
	if guard_status != null and is_instance_valid(context.caster.status_controller):
		context.caster.status_controller.add_status(guard_status, context.caster, lock_key, 1, guard_seconds)
	visual = DirectionalGuardVisual.new()
	visual.rotation = context.locked_direction.angle()
	visual.angle_degrees = front_angle
	context.caster.add_child(visual)


func _process(delta: float) -> void:
	if active_context == null:
		return
	if not _can_continue():
		_finish(false)
		return
	if counter_pending:
		_finish(true)
		return
	elapsed += maxf(delta, 0.0)
	if is_instance_valid(visual):
		visual.perfect = elapsed <= perfect_seconds
		visual.queue_redraw()
	if elapsed >= guard_seconds:
		_finish(false)


func _can_continue() -> bool:
	return EventBus.is_battle_active and active_context.is_caster_action_valid() and active_context.caster.can_act()


func _on_incoming(data: DamageData) -> void:
	if active_context == null or not _can_continue() or elapsed >= guard_seconds:
		return
	if data == null or data.final_damage <= 0.0 or not _is_frontal_attack(data):
		return
	var precise: bool = not counter_pending and elapsed <= maxf(perfect_seconds, 0.0)
	data.final_damage *= 1.0 - clampf(perfect_reduction if precise else damage_reduction, 0.0, 1.0)
	if precise:
		counter_pending = true


func _is_frontal_attack(data: DamageData) -> bool:
	var caster: Entity = active_context.caster
	if data.target != caster or data.source == caster:
		return false
	for tag: String in ["status", "periodic", "terrain", "self_damage", "reflect", "retaliation"]:
		if data.tags.has(tag):
			return false
	var toward_source: Vector2 = -data.impact_direction
	if toward_source.is_zero_approx() and is_instance_valid(data.source):
		toward_source = caster.global_position.direction_to(data.source.global_position)
	if toward_source.is_zero_approx():
		return false
	return active_context.locked_direction.normalized().dot(toward_source.normalized()) >= cos(deg_to_rad(front_angle * 0.5))


func _finish(counter: bool) -> void:
	var context: AbilityContext = active_context
	active_context = null
	counter_pending = false
	if is_instance_valid(visual):
		visual.queue_free()
	visual = null
	if is_instance_valid(controller):
		controller.clear_cast_block_modifier(lock_key)
	controller = null
	if context == null or not is_instance_valid(context.caster):
		return
	var caster: Entity = context.caster
	if caster.damage_receive_prepared.is_connected(_on_incoming):
		caster.damage_receive_prepared.disconnect(_on_incoming)
	if is_instance_valid(caster.stats_controller):
		caster.stats_controller.clear_effect_modifiers(lock_key)
	if guard_status != null and is_instance_valid(caster.status_controller):
		caster.status_controller.remove_status_source(guard_status.id, lock_key)
	if not counter or not EventBus.is_battle_active or not context.is_caster_action_valid() or not caster.can_act():
		return
	caster.spend_energy(-maxf(perfect_energy_refund, 0.0))
	for child: Node in get_children():
		if not context.is_caster_action_valid():
			break
		if child is AbilityComponent and child.auto_activate:
			child.activate(context)


func _exit_tree() -> void:
	_finish(false)
