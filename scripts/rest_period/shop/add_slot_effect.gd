class_name AddSlotEffect
extends ShopEffect

@export var add_count: int = 1


# 扩充商店可售卖槽位数量，并同步补齐 Shop.current_slot。
func apply(shop: Shop) -> void:
	if shop == null or add_count <= 0:
		return

	shop.slot_count += add_count

	while shop.current_slot.size() < shop.slot_count:
		shop.current_slot.append(Slot.new())
