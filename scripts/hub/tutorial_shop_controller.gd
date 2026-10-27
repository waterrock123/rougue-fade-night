extends ShopController

var lesson_relic: Relic


## 只覆盖教学货架生成，不改变正式商店的二次确认、付款与入包链路。
func _roll_slots(_start_index: int) -> void:
	if shop == null:
		return
	shop.ensure_slot_count()
	for index: int in range(shop.current_slot.size()):
		shop.current_slot[index].item = lesson_relic if index == 0 else null


func _update_shop_ui() -> void:
	super._update_shop_ui()
	refresh_button.hide()
	freeze_button.hide()
	level_up_button.hide()


func refresh() -> void:
	pass


func refresh_for_free() -> void:
	pass


func frezee() -> void:
	pass


func level_up() -> void:
	pass
