## 击杀敌人时按概率获得金币。
## 用于“陨铁弹药”升级态这类低概率经济收益。
class_name KillChanceGoldEffect
extends RelicEffect

@export_range(0.0, 1.0, 0.0001) var trigger_chance: float = 0.005
@export var gold_amount: int = 1

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return

	active_contexts[str(effect_key)] = relic_context
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _on_enemy_killed(_enemy: Entity, killer: Entity) -> void:
	if killer == null:
		return

	for context_value in active_contexts.values():
		var relic_context := context_value as RelicContext
		if relic_context == null or killer != relic_context.owner:
			continue
		if randf() <= trigger_chance:
			_add_gold(killer)


func _add_gold(owner: Node) -> void:
	var run_stats := _resolve_run_stats(owner)
	if run_stats == null:
		return

	run_stats.set_gold(run_stats.gold + max(gold_amount, 0))


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null
