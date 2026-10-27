## 条件门：实际移动速度或指定面板属性低于阈值时，启用一组独立的遗物效果。
## 本脚本仅管理条件与生命周期，不实现伤害、发射或属性加成，便于组合复用。
class_name ConditionalRelicEffect
extends RelicEffect

@export var use_actual_speed: bool = true
@export var stat_name: StringName = &"move_speed"
@export var threshold: float = 50.0
@export_range(0.01, 1.0, 0.01) var check_interval: float = 0.05
@export var conditional_effects: Array[RelicEffect] = []

var runners: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var key: String = "%s:%s" % [context.owner.get_instance_id(), effect_key]
	if runners.has(key) and is_instance_valid(runners[key].get_ref()):
		return
	var runner: ConditionalRelicEffectRunner = ConditionalRelicEffectRunner.new()
	runner.name = "ConditionalRelicEffect"
	runner.context = context
	runner.source_key = key
	runner.effects = conditional_effects
	runner.use_actual_speed = use_actual_speed
	runner.stat_name = stat_name
	runner.threshold = threshold
	runner.check_interval = check_interval
	runners[key] = weakref(runner)
	runner.tree_exiting.connect(_forget_runner.bind(key), CONNECT_ONE_SHOT)
	context.owner.add_child(runner)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var key: String = "%s:%s" % [context.owner.get_instance_id(), effect_key]
	if not runners.has(key):
		return
	var value: Variant = runners[key].get_ref()
	runners.erase(key)
	if is_instance_valid(value):
		var runner: ConditionalRelicEffectRunner = value as ConditionalRelicEffectRunner
		runner.stop()
		# 装备刷新可能紧接着创建新一代 runner，先断开旧节点退出时的清理回调。
		var callback: Callable = _forget_runner.bind(key)
		if runner.tree_exiting.is_connected(callback):
			runner.tree_exiting.disconnect(callback)
		runner.queue_free()


func _forget_runner(key: String) -> void:
	runners.erase(key)
