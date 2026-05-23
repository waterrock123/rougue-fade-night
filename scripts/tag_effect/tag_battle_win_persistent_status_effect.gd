## 套装效果：战斗胜利时把某个状态记录为跨战斗保留的层数，并在进入场景时重新施加。
class_name TagBattleWinPersistentStatusEffect
extends TagEffect

@export var status_data: StatusData
@export var stacks_per_win: int = 1

var active_contexts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	_apply_saved_status(context)
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
		_gain_status_stack(context)


func _gain_status_stack(context: TagEffectContext) -> void:
	if context.run_stats == null or status_data == null:
		return

	context.run_stats.add_persistent_status_stacks(status_data.id, stacks_per_win)
	_apply_saved_status(context)


func _apply_saved_status(context: TagEffectContext) -> void:
	if context == null or context.run_stats == null or status_data == null:
		return

	var stacks := context.run_stats.get_persistent_status_stacks(status_data.id)
	if stacks <= 0:
		return

	var status_controller := TagEffectRuntimeHelper.get_status_controller(context.effect_owner)
	if status_controller == null:
		return

	# 先移除同来源旧层数，再按 RunStats 中保存的层数重放，避免 ADD_STACK 状态被重复累加。
	status_controller.remove_status_source(status_data.id, _get_status_source_key())
	status_controller.add_status(status_data, context.effect_owner, _get_status_source_key(), stacks)


func _get_status_source_key() -> String:
	return "persistent_tag_status_%s" % String(status_data.id)
