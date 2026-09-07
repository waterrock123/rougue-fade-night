## 每次战斗胜利后，把一级属性加成永久记录在“这件遗物自身”上的通用效果。
## 用于古剑这类会随战斗次数成长的装备；数值写入 Relic.accumulated_stat_bonuses，因此可随存档保留。
class_name BattleWinAccumulateRelicStatsEffect
extends RelicEffect

@export var add_stats_per_win: Dictionary = {}

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or add_stats_per_win.is_empty():
		return

	var context_id: String = _get_context_id(owner, effect_key)
	active_contexts[context_id] = {
		"relic_context": relic_context,
		"effect_key": effect_key,
	}
	_refresh_relic_bonus(relic_context, effect_key)
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		return

	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.clear_effect_modifiers(effect_key)
	active_contexts.erase(_get_context_id(owner, effect_key))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	for record_value in active_contexts.values():
		var record: Dictionary = record_value as Dictionary
		var relic_context: RelicContext = record.get("relic_context") as RelicContext
		var effect_key = record.get("effect_key")
		_accumulate_relic_bonus(relic_context)
		_refresh_relic_bonus(relic_context, effect_key)


func _accumulate_relic_bonus(relic_context: RelicContext) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return

	for stat_name_variant in add_stats_per_win.keys():
		var stat_name: String = str(stat_name_variant)
		var old_amount: float = float(relic_context.own_relic.accumulated_stat_bonuses.get(stat_name, 0.0))
		var increment: float = float(add_stats_per_win[stat_name_variant])
		relic_context.own_relic.accumulated_stat_bonuses[stat_name] = old_amount + increment


func _refresh_relic_bonus(relic_context: RelicContext, effect_key) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null or relic_context == null or relic_context.own_relic == null:
		return

	var modifiers: Array[Modifier] = []
	for stat_name_variant in relic_context.own_relic.accumulated_stat_bonuses.keys():
		var amount: float = float(relic_context.own_relic.accumulated_stat_bonuses[stat_name_variant])
		if amount != 0.0:
			modifiers.append(Modifier.create_flat(StringName(stat_name_variant), amount, effect_key))
	stats_controller.set_effect_modifiers(effect_key, modifiers)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	return (relic_context.owner as Entity).stats_controller if relic_context.owner is Entity else null


func _get_context_id(owner: Entity, effect_key) -> String:
	return "%s_%s" % [str(owner.get_instance_id()), str(effect_key)]
