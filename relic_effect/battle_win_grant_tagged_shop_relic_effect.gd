## 战斗胜利后，从当前商人货池里随机获得一件带指定 tag 的装备。
## 这是“战斗后产出加工品/特定流派装备”的通用效果，具体筛选条件由资源配置决定。
class_name BattleWinGrantTaggedShopRelicEffect
extends RelicEffect


## 候选装备必须包含这些 tag 之一；为空时不限制 tag。
@export var required_tags: Array[RelicTag] = []
## 生成装备的等级。小于 0 时使用当前商店等级 + level_offset。
@export var fixed_level: int = -1
@export var level_offset: int = 0
## 开启后允许从不高于目标等级的候选里随机，适合“获得不高于当前商店等级的加工品”。
@export var allow_lower_level: bool = false
## 升级态遗物触发时，获得的装备是否直接变为升级态。
@export var levelup_granted_relic_when_owner_levelup: bool = false

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if _get_owner_entity(relic_context) == null:
		return

	var key := str(effect_key)
	active_contexts[key] = relic_context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	_disconnect_if_idle()


func _on_battle_rewards_resolving() -> void:
	var contexts := active_contexts.duplicate()
	for context_value in contexts.values():
		_grant_relic(context_value as RelicContext)


func _grant_relic(relic_context: RelicContext) -> void:
	if relic_context == null:
		return

	var run_stats := _resolve_run_stats(relic_context.owner)
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates := _collect_candidates(run_stats, relic_context)
	if candidates.is_empty():
		return

	var template = RunRng.pick(candidates) as Relic
	if template == null:
		return
	var relic := template.duplicate(true) as Relic
	if levelup_granted_relic_when_owner_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		relic.leveltip = Relic.LevelTip.LEVELUP

	run_stats.player_build.add_relic(relic)


func _collect_candidates(run_stats: RunStats, _relic_context: RelicContext) -> Array[Relic]:
	var result: Array[Relic] = []
	var shop_keeper := _get_shop_keeper(run_stats)
	if shop_keeper == null:
		return result

	var target_level := _get_target_level(run_stats)
	for relic in shop_keeper.relics:
		if relic == null:
			continue
		if target_level >= 0 and not _matches_level(relic.level, target_level):
			continue
		if not _matches_required_tags(relic):
			continue
		result.append(relic)

	return result


func _matches_level(relic_level: int, target_level: int) -> bool:
	if allow_lower_level:
		return relic_level <= target_level
	return relic_level == target_level


func _get_shop_keeper(run_stats: RunStats) -> ShopKeeper:
	if run_stats != null and run_stats.shop != null and run_stats.shop.shopkeeper != null:
		return run_stats.shop.shopkeeper
	return null


func _get_target_level(run_stats: RunStats) -> int:
	if fixed_level >= 0:
		return fixed_level
	var shop_level := 0
	if run_stats != null and run_stats.shop != null:
		shop_level = run_stats.shop.level
	return max(shop_level + level_offset, 0)


func _matches_required_tags(relic: Relic) -> bool:
	if required_tags.is_empty():
		return true
	for required_tag in required_tags:
		if required_tag != null and relic.tags.has(required_tag):
			return true
	return false


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null


func _disconnect_if_idle() -> void:
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)
