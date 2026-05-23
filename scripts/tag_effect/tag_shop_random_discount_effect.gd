## 套装效果：进入修整期时，有概率让当前商店中的若干商品获得随机折扣。
class_name TagShopRandomDiscountEffect
extends TagEffect

@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.35
@export_range(0.01, 1.0, 0.01) var min_price_rate: float = 0.55
@export_range(0.01, 1.0, 0.01) var max_price_rate: float = 0.85
@export var discounted_slot_count: int = 1

var active_contexts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	if not EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.connect(_on_rest_period_started)


func on_deactivate(context: TagEffectContext) -> void:
	active_contexts.erase(TagEffectRuntimeHelper.get_context_key(context))
	if active_contexts.is_empty() and EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.disconnect(_on_rest_period_started)


func _on_rest_period_started() -> void:
	for value in active_contexts.values():
		var context := value as TagEffectContext
		if context != null:
			_try_apply_discount(context)


func _try_apply_discount(context: TagEffectContext) -> void:
	if context.run_stats == null or context.run_stats.shop == null:
		return
	if RunRng.randf() > trigger_chance:
		return

	var filled_slots := _collect_discountable_slots(context.run_stats.shop)
	if filled_slots.is_empty():
		return

	RunRng.shuffle_array(filled_slots)
	var count = min(max(discounted_slot_count, 1), filled_slots.size())
	for index in range(count):
		_discount_slot(filled_slots[index] as Slot)

	EventBus.shop_inventory_update.emit()


func _collect_discountable_slots(shop: Shop) -> Array[Slot]:
	var result: Array[Slot] = []
	for slot in shop.current_slot:
		if slot == null or slot.item == null:
			continue
		if slot.item.price <= 0:
			continue
		result.append(slot)
	return result


func _discount_slot(slot: Slot) -> void:
	if slot == null or slot.item == null:
		return

	var from_rate = min(min_price_rate, max_price_rate)
	var to_rate = max(min_price_rate, max_price_rate)
	var price_rate := RunRng.randf_range(from_rate, to_rate)
	slot.item.price = max(int(round(slot.item.price * price_rate)), 0)
