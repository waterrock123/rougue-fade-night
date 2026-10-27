extends "res://scripts/hub/tutorial_shop_controller.gd"

signal tutorial_shop_changed()
var tutorial_config: MergeTutorialConfig
var material_purchased: bool = false
var reward_enabled: bool = false
var reward_index: int = 0
var selected_reward: Relic
var reward_was_free: bool = false
var expected_shelf: Array[Dictionary] = []


func _roll_slots(_start_index: int) -> void:
	shop.ensure_slot_count()
	shop.current_slot[0].item = lesson_relic
	for index: int in range(1, shop.current_slot.size()):
		var relic: Relic = tutorial_config.ordinary_extras[index - 1].duplicate(true) as Relic
		relic.initialize_shop_price_reference()
		shop.current_slot[index].item = relic


## 仅限制教学顺序，付款、真实合成、领取和货架恢复仍走 ShopController。
func buy_relic(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop.current_slot.size():
		return
	if is_free_choice_active:
		if not reward_enabled:
			return
		var candidate: Relic = shop.current_slot[slot_index].item
		var previous_gold: int = run_stats.gold
		super.buy_relic(slot_index)
		if not is_free_choice_active and candidate != null and _owns_relic(candidate):
			selected_reward = candidate
			reward_was_free = candidate.price == 0 and previous_gold == run_stats.gold
	else:
		if material_purchased or slot_index != 0:
			return
		super.buy_relic(slot_index)
		material_purchased = lesson_relic != null and shop.current_slot[0].item != lesson_relic
	_sync_shop_ui()
	tutorial_shop_changed.emit()


func _sync_shop_ui() -> void:
	super._sync_shop_ui()
	for button: ShopEquipButton in shop_slots:
		button.disabled = not reward_enabled if is_free_choice_active else material_purchased or button.slot_index != 0 or button.is_empty()


func set_reward_enabled(enabled: bool) -> void:
	reward_enabled = enabled
	_sync_shop_ui()


func _roll_free_choice_slots(choice_level: int) -> bool:
	reward_index = 0
	return super._roll_free_choice_slots(choice_level)


func _get_available_relics_by_level(relic_level: int) -> Array[Relic]:
	var result: Array[Relic] = []
	for relic: Relic in tutorial_config.reward_relics:
		if relic != null and relic.level == relic_level:
			result.append(relic)
	return result


## 顺序挑选教学候选，不消费 RunRng；零价格仍由真实三选一流程设置。
func _pick_random_relic(candidates: Array[Relic]) -> Relic:
	if candidates.is_empty():
		return null
	var relic: Relic = candidates[reward_index % candidates.size()].duplicate(true) as Relic
	reward_index += 1
	relic.initialize_shop_price_reference()
	return relic


func _save_shop_state() -> void:
	super._save_shop_state()
	expected_shelf = _shelf_snapshot(saved_shop_slots, saved_frozen_slots)


func has_restored_shelf() -> bool:
	return not is_free_choice_active and not expected_shelf.is_empty() and _shelf_snapshot(shop.current_slot, shop.frozen_slots) == expected_shelf


func _shelf_snapshot(slots: Array[Slot], frozen: Array[bool]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(slots.size()):
		var relic: Relic = slots[index].item if slots[index] != null else null
		result.append({"id": relic.id if relic != null else "", "level": relic.level if relic != null else -1, "tip": relic.leveltip if relic != null else -1, "price": relic.price if relic != null else 0, "frozen": frozen[index] if index < frozen.size() else false})
	return result


func _owns_relic(relic: Relic) -> bool:
	var build: PlayerBuild = run_stats.player_build
	for slots: Array in [build.player_inventory.slots, build.player_equipment.equip_slots]:
		for slot: Slot in slots:
			if slot != null and slot.item == relic:
				return true
	return false
