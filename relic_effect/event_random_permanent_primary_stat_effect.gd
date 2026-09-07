## 在“战斗胜利”或“获得永久遗物”时，永久提高随机一级属性的通用遗物效果。
## 购买/事件奖励由 PlayerBuild.add_relic 统一发出 relic_added，避免各入口重复写属性成长逻辑。
class_name EventRandomPermanentPrimaryStatEffect
extends RelicEffect

@export var trigger_on_battle_win: bool = true
@export var trigger_on_relic_added: bool = true
@export var points_per_trigger: int = 1

var battle_contexts: Dictionary = {}
var relic_added_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or points_per_trigger <= 0:
		return

	if relic_context.owner is Entity and trigger_on_battle_win:
		battle_contexts[_get_context_id(relic_context, effect_key)] = relic_context
	if relic_context.owner is PlayerBuildProxy and trigger_on_relic_added:
		relic_added_contexts[_get_context_id(relic_context, effect_key)] = relic_context

	if not battle_contexts.is_empty() and not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)
	if not relic_added_contexts.is_empty() and not EventBus.relic_added.is_connected(_on_relic_added):
		EventBus.relic_added.connect(_on_relic_added)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var context_id: String = _get_context_id(relic_context, effect_key)
	battle_contexts.erase(context_id)
	relic_added_contexts.erase(context_id)
	if battle_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)
	if relic_added_contexts.is_empty() and EventBus.relic_added.is_connected(_on_relic_added):
		EventBus.relic_added.disconnect(_on_relic_added)


func _on_battle_rewards_resolving() -> void:
	for context_value in battle_contexts.values():
		_apply_random_stat(context_value as RelicContext)


func _on_relic_added(_relic: Relic, receiver: PlayerBuild) -> void:
	for context_value in relic_added_contexts.values():
		var relic_context: RelicContext = context_value as RelicContext
		if _get_player_build(relic_context) == receiver:
			_apply_random_stat(relic_context)


func _apply_random_stat(relic_context: RelicContext) -> void:
	var player_build: PlayerBuild = _get_player_build(relic_context)
	if player_build == null or player_build.player_stats == null:
		return

	var stat_names: Array[StringName] = [
		&"strength", &"dexterity", &"intelligence", &"constitution", &"speed", &"charm", &"luck",
	]
	var selected_stat: StringName = StringName(RunRng.pick(stat_names))
	match selected_stat:
		&"strength": player_build.player_stats.strength += points_per_trigger
		&"dexterity": player_build.player_stats.dexterity += points_per_trigger
		&"intelligence": player_build.player_stats.intelligence += points_per_trigger
		&"constitution": player_build.player_stats.constitution += points_per_trigger
		&"speed": player_build.player_stats.speed += points_per_trigger
		&"charm": player_build.player_stats.charm += points_per_trigger
		&"luck": player_build.player_stats.luck += points_per_trigger

	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.bind_player_build(player_build)
	EventBus.attribute_update.emit()


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner is Entity:
		var stats_controller: StatsController = (relic_context.owner as Entity).stats_controller
		return stats_controller.player_build if stats_controller != null else null
	return null


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	return relic_context.owner.get_node_or_null("StatsController") as StatsController if relic_context.owner != null else null


func _get_context_id(relic_context: RelicContext, effect_key) -> String:
	var owner_id: int = relic_context.owner.get_instance_id() if relic_context != null and relic_context.owner != null else 0
	return "%s_%s" % [str(owner_id), str(effect_key)]
