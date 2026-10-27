## 定时技能流程：启动子组件，等待包含恢复窗口的总时长，再通知 AI 完成。
## 中断只报告失败，不把被取消的攻击计入 Boss 的出招次数。
class_name AbilityTimedSequence
extends AbilityComponent

signal sequence_finished(context: AbilityContext, completed: bool)

@export var total_duration: float = 2.0
## 大于零时，二阶段使用独立总时长，为追加攻击保留恢复窗口。
@export var phase_two_duration: float = 0.0
@export var animation_name: StringName = &"attack"
var active_context: AbilityContext
var remaining: float = 0.0


func _activate(context: AbilityContext) -> void:
	active_context = context
	remaining = maxf(total_duration, 0.01)
	if phase_two_duration > 0.0 and context.caster.has_method("get_encounter_phase") and context.caster.call("get_encounter_phase") == 2:
		remaining = phase_two_duration
	context.caster.lock_movement(remaining)
	if animation_name != &"":
		context.caster.play_animation(AnimationWrapper.new(String(animation_name), true))
	for child: Node in get_children():
		if child is AbilityComponent and child.auto_activate:
			child.activate(context)


func _process(delta: float) -> void:
	if active_context == null:
		return
	if not active_context.is_caster_action_valid():
		_finish(false)
		return
	# 控制状态直接取消旧动作，使所有已排队的延迟组件同时失效。
	if not active_context.caster.can_act():
		active_context.caster.cancel_active_actions()
		_finish(false)
		return
	remaining -= delta
	if remaining <= 0.0:
		_finish(true)


func _finish(completed: bool) -> void:
	var context: AbilityContext = active_context
	active_context = null
	if is_instance_valid(context.caster) and not context.caster.is_dead:
		context.caster.current_anim = null
	sequence_finished.emit(context, completed)
