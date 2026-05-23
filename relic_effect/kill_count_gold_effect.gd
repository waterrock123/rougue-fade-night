## 遗物效果：按击杀数量发放金币。
## 适合“每击杀 N 个敌人获得金币”这类可以跨战斗累计的装备效果。
class_name KillCountGoldEffect
extends RelicEffect


## 每累计多少次击杀发放一次奖励。
@export var kills_per_reward: int = 20
## 未升级时每次奖励的金币。
@export var gold_per_reward: int = 1
## 升级态时每次奖励的金币。小于 0 时会沿用 gold_per_reward。
@export var levelup_gold_per_reward: int = -1

var _active_contexts: Dictionary = {}
var _kill_counts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner(relic_context)
	if owner == null:
		return

	var key := str(effect_key)
	_active_contexts[key] = relic_context

	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.battle_rewards_resolving.is_connected(_cleanup_all_connections):
		EventBus.battle_rewards_resolving.connect(_cleanup_all_connections)
	if not EventBus.battle_lost.is_connected(_cleanup_all_connections):
		EventBus.battle_lost.connect(_cleanup_all_connections)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	_active_contexts.erase(key)
	if _active_contexts.is_empty():
		_cleanup_all_connections()


func _on_enemy_killed(enemy: Entity, killer: Entity) -> void:
	if enemy == null or killer == null:
		return
	if kills_per_reward <= 0:
		return

	for effect_key in _active_contexts.keys():
		var relic_context := _active_contexts[effect_key] as RelicContext
		if relic_context == null or killer != relic_context.owner:
			continue

		_handle_context_kill(killer, relic_context, str(effect_key))


func _handle_context_kill(killer: Entity, relic_context: RelicContext, effect_key: String) -> void:
	var run_stats := _resolve_run_stats(killer)
	if run_stats == null:
		return

	_kill_counts[effect_key] = int(_kill_counts.get(effect_key, 0)) + 1
	var reward_times := 0
	while int(_kill_counts[effect_key]) >= kills_per_reward:
		_kill_counts[effect_key] = int(_kill_counts[effect_key]) - kills_per_reward
		reward_times += 1

	if reward_times <= 0:
		return

	var reward_gold := _get_reward_gold(relic_context) * reward_times
	if reward_gold > 0:
		run_stats.set_gold(run_stats.gold + reward_gold)


func _get_reward_gold(relic_context: RelicContext) -> int:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_gold_per_reward >= 0:
			return levelup_gold_per_reward
	return gold_per_reward


func _cleanup_all_connections() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.battle_rewards_resolving.is_connected(_cleanup_all_connections):
		EventBus.battle_rewards_resolving.disconnect(_cleanup_all_connections)
	if EventBus.battle_lost.is_connected(_cleanup_all_connections):
		EventBus.battle_lost.disconnect(_cleanup_all_connections)

	_active_contexts.clear()


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity


func _resolve_run_stats(owner: Node) -> RunStats:
	if owner == null:
		return null
	if "run_stats" in owner:
		return owner.run_stats

	var node := owner.get_parent()
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null
