## 每场战斗一次，以永久属性代价阻止死亡并恢复一定比例生命。
## 使用实体元数据保留次数，装备刷新不会重新获得复活机会；新战斗实体会自然重置。
class_name PreventDeathOnceEffect
extends RelicEffect

@export_range(0.01, 1.0, 0.01) var health_fraction: float = 0.2
@export var permanent_cost: UsePermanentStatsEffect
@export var usage_key: StringName = &"revive_once"

var connections: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Player):
		return
	var entity: Entity = context.owner as Entity
	var key: String = "%s:%s" % [entity.get_instance_id(), effect_key]
	if connections.has(key):
		return
	var callback: Callable = _prevent_death.bind(context)
	var exit_callback: Callable = _disconnect.bind(key)
	entity.death_prevent_requested.connect(callback)
	entity.tree_exiting.connect(exit_callback, CONNECT_ONE_SHOT)
	connections[key] = {"owner": weakref(entity), "callback": callback, "exit": exit_callback}


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context != null and is_instance_valid(context.owner):
		_disconnect("%s:%s" % [context.owner.get_instance_id(), effect_key])


func _disconnect(key: String) -> void:
	var entry: Dictionary = connections.get(key, {})
	connections.erase(key)
	if entry.is_empty():
		return
	var value: Variant = entry["owner"].get_ref()
	if not is_instance_valid(value):
		return
	var entity: Entity = value as Entity
	if entity.death_prevent_requested.is_connected(entry["callback"]):
		entity.death_prevent_requested.disconnect(entry["callback"])
	if entity.tree_exiting.is_connected(entry["exit"]):
		entity.tree_exiting.disconnect(entry["exit"])


func _prevent_death(context: RelicContext) -> void:
	if not is_instance_valid(context.owner):
		return
	var entity: Entity = context.owner as Entity
	if entity.is_dead or entity.current_health > 0.0 or entity.get_meta(usage_key, false):
		return
	entity.set_meta(usage_key, true)
	# 先支付永久属性代价，再按修改后的最大生命计算恢复量；位置保持不变。
	if permanent_cost != null:
		permanent_cost.on_use(context, str(usage_key))
	entity.current_health = 0.0
	if entity.stats_controller != null:
		entity.stats_controller.current_health = 0.0
	entity.apply_heal(maxf(entity.get_runtime_max_health() * health_fraction, 1.0))
