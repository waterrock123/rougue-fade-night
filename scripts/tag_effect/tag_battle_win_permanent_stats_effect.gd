## 套装效果：战斗胜利结算时永久提升 PlayerBuild 的基础/派生属性。
class_name TagBattleWinPermanentStatsEffect
extends TagEffect

@export var stat_bonuses: Dictionary = {}

var active_contexts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(context: TagEffectContext) -> void:
	active_contexts.erase(TagEffectRuntimeHelper.get_context_key(context))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	for value in active_contexts.values():
		var context := value as TagEffectContext
		if context == null or TagEffectRuntimeHelper.get_owner_entity(context) == null:
			continue
		_apply_permanent_stats(context)


func _apply_permanent_stats(context: TagEffectContext) -> void:
	if context.player_build == null or context.player_build.player_stats == null:
		return

	var stats_data := context.player_build.player_stats
	for stat_name in stat_bonuses.keys():
		_apply_one_stat(stats_data, StringName(stat_name), stat_bonuses[stat_name])
	if context.stats_controller != null:
		context.stats_controller.bind_player_build(context.player_build)
	EventBus.attribute_update.emit()


func _apply_one_stat(stats_data: StatsData, stat_name: StringName, amount_value) -> void:
	var int_amount := int(amount_value)
	var float_amount := float(amount_value)
	match stat_name:
		&"strength":
			stats_data.strength += int_amount
		&"dexterity":
			stats_data.dexterity += int_amount
		&"intelligence":
			stats_data.intelligence += int_amount
		&"constitution":
			stats_data.constitution += int_amount
		&"speed":
			stats_data.speed += int_amount
		&"charm":
			stats_data.charm += int_amount
		&"luck":
			stats_data.luck += int_amount
		&"base_damage_reduction_rate":
			stats_data.base_damage_reduction_rate += float_amount
		&"base_static_damage_reduction":
			stats_data.base_static_damage_reduction += int_amount
