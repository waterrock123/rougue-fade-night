## 遗物效果：战斗结束时按概率获得可储存的免费商店刷新次数。
## 适合“启示面具”这类战斗胜利后影响修整期运营的装备。
class_name BattleEndShopRefreshChanceEffect
extends RelicEffect


## 未升级时触发概率。
@export_range(0.0, 1.0, 0.01) var chance: float = 0.25
## 升级态触发概率。小于 0 时沿用 chance。
@export_range(-1.0, 1.0, 0.01) var levelup_chance: float = -1.0
## 成功后获得的免费刷新次数。
@export var refresh_count: int = 1

var _active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner(relic_context)
	if owner == null:
		return

	var key := str(effect_key)
	_active_contexts[key] = relic_context

	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	_active_contexts.erase(key)
	if _active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	var contexts := _active_contexts.duplicate()
	_active_contexts.clear()
	if EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)

	for relic_context in contexts.values():
		_try_grant_refresh(relic_context as RelicContext)


func _try_grant_refresh(relic_context: RelicContext) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if refresh_count <= 0:
		return

	var trigger_chance := _get_current_chance(relic_context)
	if randf() > trigger_chance:
		return

	var run_stats := _resolve_run_stats(relic_context.owner)
	if run_stats != null:
		run_stats.add_shop_free_refresh_count(refresh_count)


func _get_current_chance(relic_context: RelicContext) -> float:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_chance >= 0.0:
			return levelup_chance
	return chance


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
