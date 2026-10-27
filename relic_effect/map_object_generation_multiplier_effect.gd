## 提高某类地图物体的随机生成概率与数量，不影响手工放置的标记物体。
class_name MapObjectGenerationMultiplierEffect
extends RelicEffect

## 留空匹配所有特殊物体，不包括火海、冰面等特殊地形。
@export var feature_tag: StringName = &"beneficial_plant"
@export var generation_bonus: float = 0.5


func on_activate(context: RelicContext, effect_key) -> void:
	var stats: RunStats = _get_run_stats(context)
	if stats != null:
		stats.set_map_object_generation_modifier(str(effect_key), context.owner.get_instance_id(), feature_tag, generation_bonus)


func on_deactivate(context: RelicContext, effect_key) -> void:
	var stats: RunStats = _get_run_stats(context)
	if stats != null:
		stats.clear_map_object_generation_modifier(str(effect_key), context.owner.get_instance_id())


func _get_run_stats(context: RelicContext) -> RunStats:
	if context == null or not is_instance_valid(context.owner):
		return null
	var node: Node = context.owner
	while node != null:
		for property: Dictionary in node.get_property_list():
			if property["name"] == "run_stats":
				var value: Variant = node.get("run_stats")
				if value is RunStats:
					return value as RunStats
		node = node.get_parent()
	return null
