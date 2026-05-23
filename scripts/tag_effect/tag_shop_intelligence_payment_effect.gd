## 套装效果：金币为 0 时，允许永久消耗智力来购买商店商品。
class_name TagShopIntelligencePaymentEffect
extends TagEffect

@export var intelligence_cost_per_purchase: int = 3

var active_keys: Array[String] = []


func on_activate(context: TagEffectContext) -> void:
	if context == null or context.run_stats == null:
		return

	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty() or active_keys.has(key):
		return

	active_keys.append(key)
	context.run_stats.set_shop_intelligence_payment(key, intelligence_cost_per_purchase)


func on_deactivate(context: TagEffectContext) -> void:
	if context == null or context.run_stats == null:
		return

	var key := TagEffectRuntimeHelper.get_context_key(context)
	active_keys.erase(key)
	context.run_stats.clear_shop_intelligence_payment(key)
