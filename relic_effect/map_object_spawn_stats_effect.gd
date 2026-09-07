class_name MapObjectSpawnStatsEffect
extends RelicEffect

## 当指定地图物体生成时，为装备者添加一份战斗内状态。
@export var object_id: StringName
@export var add_stats: Dictionary = {}
@export var status_name: String = "地图物体增益"
@export_multiline var status_desc: String = "地图物体出现后获得的战斗内增益。"
@export var status_icon: Texture2D

var active_contexts: Dictionary = {}
var triggered_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or object_id == &"" or add_stats.is_empty():
		return
	var key: String = str(effect_key)
	active_contexts[key] = relic_context
	triggered_contexts[key] = false
	if not EventBus.map_object_spawned.is_connected(_on_map_object_spawned):
		EventBus.map_object_spawned.connect(_on_map_object_spawned)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	_remove_triggered_status(relic_context, key)
	active_contexts.erase(key)
	triggered_contexts.erase(key)
	if active_contexts.is_empty() and EventBus.map_object_spawned.is_connected(_on_map_object_spawned):
		EventBus.map_object_spawned.disconnect(_on_map_object_spawned)


func _on_map_object_spawned(map_object: Node) -> void:
	if map_object == null or not is_instance_valid(map_object) or not map_object.has_method("get_map_object_id"):
		return
	if StringName(map_object.get_map_object_id()) != object_id:
		return

	for key_variant in active_contexts.keys():
		var key: String = str(key_variant)
		if bool(triggered_contexts.get(key, false)):
			continue
		var context: RelicContext = active_contexts[key] as RelicContext
		if context == null:
			continue
		_apply_status(context, key)
		triggered_contexts[key] = true


func _apply_status(relic_context: RelicContext, effect_key: String) -> void:
	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null:
		return

	var stat_effect: StatusAddStatsEffect = StatusAddStatsEffect.new()
	stat_effect.stat_values = add_stats
	var status_data: StatusData = StatusData.new()
	status_data.id = StringName("%s_map_object_status" % effect_key)
	status_data.status_name = status_name
	status_data.desc = status_desc
	status_data.icon = status_icon
	status_data.duration = -1.0
	status_data.polarity = StatusData.Polarity.POSITIVE
	status_data.effects = [stat_effect]
	status_controller.add_status(status_data, relic_context.owner, effect_key, 1)


func _remove_triggered_status(relic_context: RelicContext, effect_key: String) -> void:
	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null:
		return
	status_controller.remove_status_source(StringName("%s_map_object_status" % effect_key), effect_key)


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null or relic_context.owner == null:
		return null
	if relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	return relic_context.owner.get_node_or_null("StatusController") as StatusController

