## 套装效果：每个修整期前几次购买后返还金币，返还量由装备栏中对应 tag 数量决定。
class_name TagPurchaseRebateEffect
extends TagEffect

@export var purchases_per_rest_period: int = 2
@export var gold_per_matching_equipped_relic: int = 1

var active_contexts: Dictionary = {}
var purchase_counts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	purchase_counts[key] = int(purchase_counts.get(key, 0))
	if not EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.connect(_on_rest_period_started)
	if not EventBus.relic_purchased.is_connected(_on_relic_purchased):
		EventBus.relic_purchased.connect(_on_relic_purchased)


func on_deactivate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	active_contexts.erase(key)
	purchase_counts.erase(key)
	if active_contexts.is_empty():
		if EventBus.rest_period_started.is_connected(_on_rest_period_started):
			EventBus.rest_period_started.disconnect(_on_rest_period_started)
		if EventBus.relic_purchased.is_connected(_on_relic_purchased):
			EventBus.relic_purchased.disconnect(_on_relic_purchased)


func _on_rest_period_started() -> void:
	for key in active_contexts.keys():
		purchase_counts[key] = 0


func _on_relic_purchased(_relic: Relic) -> void:
	for key in active_contexts.keys():
		var context := active_contexts[key] as TagEffectContext
		if context != null:
			_try_grant_rebate(str(key), context)


func _try_grant_rebate(key: String, context: TagEffectContext) -> void:
	if context.run_stats == null or context.player_build == null:
		return
	if int(purchase_counts.get(key, 0)) >= purchases_per_rest_period:
		return

	var matching_count := TagEffectRuntimeHelper.count_equipped_unique_relics_with_tag(context.player_build, tag)
	var rebate = matching_count * max(gold_per_matching_equipped_relic, 0)
	purchase_counts[key] = int(purchase_counts.get(key, 0)) + 1
	if rebate <= 0:
		return

	context.run_stats.set_gold(context.run_stats.gold + rebate)
