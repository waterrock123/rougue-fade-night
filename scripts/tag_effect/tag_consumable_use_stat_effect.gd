## 套装效果：战斗中使用消耗品时，临时获得属性加成直到本场战斗结束。
class_name TagConsumableUseStatEffect
extends TagEffect

@export var stats_per_trigger: Dictionary = {}
## 小于 0 表示不限次数；1 可实现“第一次使用消耗品时触发”。
@export var max_triggers_per_battle: int = -1

var active_contexts: Dictionary = {}
var trigger_counts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	trigger_counts[key] = int(trigger_counts.get(key, 0))
	if not EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.connect(_on_battle_started)
	if not EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.connect(_on_consumable_used)


func on_deactivate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	_clear_context_modifiers(context)
	active_contexts.erase(key)
	trigger_counts.erase(key)
	if active_contexts.is_empty():
		if EventBus.battle_started.is_connected(_on_battle_started):
			EventBus.battle_started.disconnect(_on_battle_started)
		if EventBus.consumable_used.is_connected(_on_consumable_used):
			EventBus.consumable_used.disconnect(_on_consumable_used)


func _on_battle_started() -> void:
	for key in active_contexts.keys():
		trigger_counts[key] = 0
		var context := active_contexts[key] as TagEffectContext
		_clear_context_modifiers(context)


func _on_consumable_used(_relic: Relic, user: Entity) -> void:
	for key in active_contexts.keys():
		var context := active_contexts[key] as TagEffectContext
		if context == null or context.effect_owner != user:
			continue
		_trigger_for_context(str(key), context)


func _trigger_for_context(key: String, context: TagEffectContext) -> void:
	if context.stats_controller == null:
		return

	var count := int(trigger_counts.get(key, 0))
	if max_triggers_per_battle >= 0 and count >= max_triggers_per_battle:
		return

	count += 1
	trigger_counts[key] = count
	context.stats_controller.set_effect_modifiers(_get_modifier_key(context), _build_modifiers(context, count))


func _build_modifiers(context: TagEffectContext, trigger_count: int) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for stat_name in stats_per_trigger.keys():
		var amount := float(stats_per_trigger[stat_name]) * trigger_count
		if amount != 0.0:
			result.append(Modifier.create_flat(StringName(stat_name), amount, _get_modifier_key(context)))
	return result


func _clear_context_modifiers(context: TagEffectContext) -> void:
	if context == null or context.stats_controller == null:
		return
	context.stats_controller.clear_effect_modifiers(_get_modifier_key(context))


func _get_modifier_key(context: TagEffectContext) -> String:
	return "%s_consumable_stats" % context.effect_key
