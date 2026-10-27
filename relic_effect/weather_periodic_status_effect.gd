## 指定天气下，在战斗中周期性添加状态的通用遗物效果。
class_name WeatherPeriodicStatusEffect
extends RelicEffect

@export var required_weather_id: StringName = &"sunny"
@export var status_data: StatusData
@export_range(0.05, 999.0, 0.05) var interval: float = 10.0
@export_range(1, 999, 1) var stacks: int = 1
@export_range(1, 999, 1) var levelup_stacks: int = 1

var active_records: Dictionary = {}
var pending_records: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not (context.owner is Entity) or status_data == null:
		return
	var key: String = str(effect_key)
	if active_records.has(key) or pending_records.has(key):
		return
	if EventBus.is_battle_active:
		_start_timer(context, key)
	else:
		pending_records[key] = context
		if not EventBus.battle_started.is_connected(_on_battle_started):
			EventBus.battle_started.connect(_on_battle_started)


func on_deactivate(_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	pending_records.erase(key)
	_clear_record(key)
	_disconnect_pending_signal_if_idle()


func _on_battle_started(_payload: Variant = null) -> void:
	var keys: Array = pending_records.keys()
	for key_value: Variant in keys:
		var key: String = str(key_value)
		var context: RelicContext = pending_records.get(key) as RelicContext
		pending_records.erase(key)
		_start_timer(context, key)
	_disconnect_pending_signal_if_idle()


func _start_timer(context: RelicContext, key: String) -> void:
	if context == null or not (context.owner is Entity):
		return
	var owner_entity: Entity = context.owner as Entity
	if owner_entity == null or not is_instance_valid(owner_entity):
		return
	if _get_active_weather_id(owner_entity) != required_weather_id:
		return
	var timer := Timer.new()
	timer.name = "WeatherPeriodicRelicTimer"
	timer.wait_time = max(interval, 0.05)
	timer.one_shot = false
	owner_entity.add_child(timer)
	timer.timeout.connect(_on_timer_timeout.bind(key))
	active_records[key] = {"context": context, "owner": owner_entity, "timer": timer}
	timer.start()


func _on_timer_timeout(key: String) -> void:
	var record: Dictionary = active_records.get(key, {}) as Dictionary
	var context: RelicContext = record.get("context") as RelicContext
	var owner_entity: Entity = record.get("owner") as Entity
	if context == null or owner_entity == null or not is_instance_valid(owner_entity) or owner_entity.is_dead:
		_clear_record(key)
		return
	var controller: StatusController = owner_entity.get_status_controller()
	if controller == null:
		return
	var actual_stacks: int = stacks
	if context.own_relic != null and context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		actual_stacks = levelup_stacks
	controller.add_status(status_data, owner_entity, key, actual_stacks)


func _get_active_weather_id(owner_entity: Entity) -> StringName:
	var current_node: Node = owner_entity
	while current_node != null:
		if "run_stats" in current_node:
			var run_stats_value = current_node.get("run_stats")
			if run_stats_value is RunStats:
				return (run_stats_value as RunStats).active_weather_id
		current_node = current_node.get_parent()
	return &""


func _clear_record(key: String) -> void:
	var record: Dictionary = active_records.get(key, {}) as Dictionary
	var timer: Timer = record.get("timer") as Timer
	if timer != null and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	active_records.erase(key)


func _disconnect_pending_signal_if_idle() -> void:
	if pending_records.is_empty() and EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)
