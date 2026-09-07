class_name AddMapObjectSpawnWeightEffect
extends RelicEffect

## 为某个地图物体变体增加权重。权重池会在生成时读取此运行时修正。
@export var object_id: StringName
@export var weight_bonus: float = 1.0


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var stats: RunStats = _get_run_stats(relic_context)
	if stats == null or object_id == &"":
		return
	stats.set_map_object_spawn_weight_modifier(effect_key, object_id, weight_bonus)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var stats: RunStats = _get_run_stats(relic_context)
	if stats != null:
		stats.clear_map_object_spawn_weight_modifier(effect_key)


func _get_run_stats(relic_context: RelicContext) -> RunStats:
	if relic_context == null or relic_context.owner == null:
		return null

	var current_node: Node = relic_context.owner
	while current_node != null:
		for property_info: Dictionary in current_node.get_property_list():
			if String(property_info.get("name", "")) != "run_stats":
				continue
			var value: Variant = current_node.get("run_stats")
			if value is RunStats:
				return value as RunStats
		current_node = current_node.get_parent()

	return null

