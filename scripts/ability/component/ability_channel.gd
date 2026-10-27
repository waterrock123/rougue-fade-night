## 通用原地吟唱：期间按来源锁移动与技能，成功读条后才执行子组件。
## 死亡、控制打断、移除技能和切换场景都会撤销限制，不使用跨场景的延迟协程。
class_name AbilityChannel
extends AbilityComponent

@export var channel_seconds: float = 2.0
@export var block_other_abilities: bool = true
## 战斗结束后取消尚未完成的吟唱，防止结算清理后又补发增益。
@export var require_battle_active: bool = true

var active_context: AbilityContext
var remaining: float = 0.0
var controller: AbilityController
var lock_key: String


func _activate(context: AbilityContext) -> void:
	_finish(false)
	active_context = context
	remaining = maxf(channel_seconds, 0.0)
	lock_key = "channel_%d" % get_instance_id()
	context.caster.add_movement_lock(lock_key)
	controller = context.caster.get_node_or_null("AbilityController") as AbilityController
	if block_other_abilities and is_instance_valid(controller):
		controller.set_cast_block_modifier(lock_key, {"block_all": true})
	if remaining <= 0.0:
		_finish(true)


func _process(delta: float) -> void:
	if active_context == null:
		return
	if require_battle_active and not EventBus.is_battle_active:
		_finish(false)
		return
	if not active_context.is_caster_action_valid() or not active_context.caster.can_act():
		_finish(false)
		return
	remaining -= delta
	if remaining <= 0.0:
		_finish(true)


func _finish(completed: bool) -> void:
	var context: AbilityContext = active_context
	active_context = null
	remaining = 0.0
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
	if not is_instance_valid(context.caster) or not context.is_caster_action_valid():
		return
	var ability_controller: AbilityController = context.caster.get_node_or_null("AbilityController") as AbilityController
	if is_instance_valid(ability_controller) and context.is_caster_action_valid():
		ability_controller.channel_completed.emit(context)


func _exit_tree() -> void:
	_finish(false)
