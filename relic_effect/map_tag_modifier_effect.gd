## 装备时提升地图标签效果强度与启用容量；卸下后撤销，不修改局内存档的基础容量。
class_name MapTagModifierEffect
extends RelicEffect

@export var effect_strength_bonus: float = 1.0
@export var enable_capacity_bonus: int = 5


func on_activate(context: RelicContext, effect_key) -> void:
	var stats: RunStats = _get_run_stats(context)
	if stats != null:
		stats.set_map_tag_modifier(str(effect_key), context.owner.get_instance_id(), effect_strength_bonus, enable_capacity_bonus)


func on_deactivate(context: RelicContext, effect_key) -> void:
	var stats: RunStats = _get_run_stats(context)
	if stats != null:
		stats.clear_map_tag_modifier(str(effect_key), context.owner.get_instance_id())


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
