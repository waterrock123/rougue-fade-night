## 定间隔连发实体，复用单发组件的偏移与生成配置。每一发沿释放时锁定的方向。
## 用节点自身的处理循环管理连发，死亡/控制/移除技能时停止，不留下延迟回调。
class_name AbilitySpawnManifestBurst
extends AbilitySpawnManifest

@export_range(1, 64, 1) var shot_count: int = 3
@export var shot_interval: float = 0.12
var active_context: AbilityContext
var shots_remaining: int = 0
var next_shot: float = 0.0


func can_pay_ability_cost(_context: AbilityContext) -> bool:
	return shots_remaining <= 0


func _activate(context: AbilityContext) -> void:
	active_context = context
	shots_remaining = maxi(shot_count, 1)
	next_shot = 0.0
	_advance_burst(0.0)


func _process(delta: float) -> void:
	_advance_burst(delta)


func _advance_burst(delta: float) -> void:
	if active_context == null:
		return
	if not active_context.is_caster_action_valid() or not active_context.caster.can_act():
		_clear_burst()
		return
	next_shot -= delta
	while shots_remaining > 0 and next_shot <= 0.00001:
		var emitted_context: AbilityContext = active_context
		super._activate(emitted_context)
		# 发射事件可能刷新技能栏，组件已退出场景时不再访问被清空的上下文。
		if active_context != emitted_context:
			return
		shots_remaining -= 1
		next_shot += maxf(shot_interval, 0.01)
		if not active_context.is_caster_action_valid():
			break
	if shots_remaining <= 0 or not active_context.is_caster_action_valid():
		_clear_burst()


func _clear_burst() -> void:
	active_context = null
	shots_remaining = 0
	next_shot = 0.0


func _exit_tree() -> void:
	_clear_burst()
