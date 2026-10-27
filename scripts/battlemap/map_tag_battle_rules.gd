class_name MapTagBattleRules
extends RefCounted

const DATABASE_PATH: String = "res://custom_resource/default_map_tag_influence_database.tres"


## 每个启用槽只计一份；不叠加的规则取最大值，装备强化标签效果仍可放大单份数值。
static func build_values(stats: RunStats, database: MapTagInfluenceDatabase = null) -> Dictionary:
	var result: Dictionary = {}
	if stats == null:
		return result
	if database == null:
		database = load(DATABASE_PATH) as MapTagInfluenceDatabase
	for key: String in stats.get_enabled_map_tag_keys():
		var influence: MapTagInfluenceData = stats.get_effective_map_tag_influence(database, key)
		if influence == null or not influence.enabled:
			continue
		for modifier: MapTagRuntimeModifier in influence.runtime_modifiers:
			if modifier == null:
				continue
			var previous: float = float(result.get(modifier.effect_id, 0.0))
			result[modifier.effect_id] = previous + modifier.amount if modifier.stackable else maxf(previous, modifier.amount)
	return result


static func value_for(stats: RunStats, effect_id: String) -> float:
	return float(build_values(stats).get(effect_id, 0.0))


static func find_run_stats(node: Node) -> RunStats:
	var current: Node = node
	while is_instance_valid(current):
		for property: Dictionary in current.get_property_list():
			if str(property.name) == "run_stats":
				var stats: RunStats = current.get("run_stats") as RunStats
				if stats != null:
					return stats
		current = current.get_parent()
	return null


static func find_controller(node: Node) -> MapTagBattleController:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("map_tag_battle_rules") as MapTagBattleController
