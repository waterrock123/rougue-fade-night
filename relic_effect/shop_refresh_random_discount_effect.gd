## 遗物效果：商店每次刷新后，有概率随机让若干商品降价。
## 用于优惠券、折扣券、商人关系等运营类装备效果。
class_name ShopRefreshRandomDiscountEffect
extends RelicEffect

@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.3
@export var discount_amount: int = 1
@export var discounted_slot_count: int = 1
@export var ignore_when_relic_levelup: bool = false

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if ignore_when_relic_levelup and relic_context != null and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var key := str(effect_key)
	active_contexts[key] = true
	if not EventBus.shop_refreshed.is_connected(_on_shop_refreshed):
		EventBus.shop_refreshed.connect(_on_shop_refreshed)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.shop_refreshed.is_connected(_on_shop_refreshed):
		EventBus.shop_refreshed.disconnect(_on_shop_refreshed)


func _on_shop_refreshed(shop: Shop) -> void:
	if active_contexts.is_empty() or shop == null:
		return
	if RunRng.randf() > trigger_chance:
		return

	var slots := _collect_discountable_slots(shop)
	if slots.is_empty():
		return

	RunRng.shuffle_array(slots)
	var count = min(max(discounted_slot_count, 1), slots.size())
	for index in range(count):
		_discount_slot(slots[index] as Slot)


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

	slot.item.price = max(slot.item.price - max(discount_amount, 0), 0)
