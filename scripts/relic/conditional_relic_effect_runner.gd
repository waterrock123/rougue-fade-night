## 为条件型遗物采样实际位移或面板属性，仅在条件发生变化时启用/撤销子效果。
## 作为实体子节点运行，继承暂停状态；无需全局每帧扫描实体，也不会把限时条件写入存档。
class_name ConditionalRelicEffectRunner
extends Node

var context: RelicContext
var effects: Array[RelicEffect] = []
var source_key: String
var use_actual_speed: bool = true
var stat_name: StringName = &"move_speed"
var threshold: float = 50.0
var check_interval: float = 0.05
var condition_active: bool = false
var last_position: Vector2
var timer: float = 0.0
var sampled_distance: float = 0.0


func _ready() -> void:
	var entity: Entity = _get_entity()
	if entity != null:
		last_position = entity.global_position


func _process(delta: float) -> void:
	var entity: Entity = _get_entity()
	if entity == null or entity.is_dead or not EventBus.is_battle_active:
		_set_active(false)
		timer = 0.0
		sampled_distance = 0.0
		if entity != null:
			last_position = entity.global_position
		return
	# 记录真实世界位移，墙体阻挡、冰面滑行与冲刺都会反映在实际速度中。
	sampled_distance += entity.global_position.distance_to(last_position)
	last_position = entity.global_position
	timer += delta
	if timer < check_interval:
		return
	# 跨多帧累计，避免渲染帧比物理帧快时把没有物理更新的一帧误判为站立。
	var value: float = sampled_distance / maxf(timer, 0.0001)
	timer = 0.0
	sampled_distance = 0.0
	if not use_actual_speed:
		if entity.stats_controller == null:
			_set_active(false)
			return
		value = entity.stats_controller.get_stat(stat_name)
	_set_active(value < threshold)


func _set_active(enabled: bool) -> void:
	if condition_active == enabled:
		return
	condition_active = enabled
	for index: int in range(effects.size()):
		var effect: RelicEffect = effects[index]
		if effect == null:
			continue
		var key: String = "%s_condition_%s" % [source_key, index]
		if enabled:
			effect.on_activate(context, key)
		else:
			effect.on_deactivate(context, key)


func stop() -> void:
	_set_active(false)
	set_process(false)


func _exit_tree() -> void:
	_set_active(false)


func _get_entity() -> Entity:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return null
	return context.owner as Entity
