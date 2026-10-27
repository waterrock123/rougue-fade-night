class_name CookingContestRoom
extends EventRoom

const RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")

@onready var desc_label: Label = $DescLabel
@onready var ingredient_button: EventRoomButton = $IngredientButton
@onready var dish_button: EventRoomButton = $DishButton
@onready var taste_button: EventRoomButton = $TasteButton
@onready var dish_picker: PanelContainer = $DishPicker
@onready var dish_list: VBoxContainer = $DishPicker/VBox/Scroll/DishList


func setup() -> void:
	ingredient_button.setup_button(_offer_ingredient)
	dish_button.setup_button(_open_dish_picker)
	taste_button.setup_button(_taste_food)
	_refresh_options()


func _refresh_options() -> void:
	ingredient_button.disabled = _find_exchangeable_ingredients().is_empty()
	dish_button.disabled = _find_inventory_slots("佳肴").is_empty()


## 送出随机原料后才发放同阶升级佳肴，避免背包不足时白白失去原料。
func _offer_ingredient() -> void:
	var slots: Array[Slot] = _find_exchangeable_ingredients()
	if slots.is_empty():
		return
	var slot: Slot = RunRng.pick(slots) as Slot
	var candidates: Array[Relic] = _get_relics(slot.item.level, "佳肴")
	if candidates.is_empty():
		desc_label.text = "目前没有与这件原料同阶的佳肴奖励。"
		return
	var reward: Relic = (RunRng.pick(candidates) as Relic).duplicate(true) as Relic
	reward.leveltip = Relic.LevelTip.LEVELUP
	var old_relic: Relic = slot.item
	slot.item = null
	if not run_stats.player_build.add_relic(reward):
		slot.item = old_relic
		desc_label.text = "背包空间不足，暂时无法交换。"
		return
	EventBus.relic_removed.emit(old_relic, "consumed")
	EventBus.inventory_update.emit()
	_finish(ingredient_button.get_pressed_desc())


func _open_dish_picker() -> void:
	for child: Node in dish_list.get_children():
		child.queue_free()
	for slot: Slot in _find_inventory_slots("佳肴"):
		var button := Button.new()
		button.text = "%s（%d阶）" % [slot.item.relic_name, slot.item.level]
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_present_dish.bind(slot))
		dish_list.add_child(button)
	dish_picker.show()


## 文案只要求“展示”佳肴，故不消耗所选装备；奖励发放前检查可用背包空间。
func _present_dish(slot: Slot) -> void:
	if slot == null or slot.item == null or not _has_tag(slot.item, "佳肴"):
		return
	var level: int = slot.item.level
	var reward_count: int = 2 if level <= 3 else 1
	var candidates: Array[Relic] = _get_relics(level)
	if candidates.is_empty() or _free_inventory_slots() < reward_count:
		desc_label.text = "同阶奖励不足或背包空间不够，请整理背包后重试。"
		return
	var rewards: Array[Relic] = []
	for index: int in range(reward_count):
		var reward: Relic = (RunRng.pick(candidates) as Relic).duplicate(true) as Relic
		if level >= 4:
			reward.leveltip = Relic.LevelTip.LEVELUP
		rewards.append(reward)
	for reward: Relic in rewards:
		run_stats.player_build.add_relic(reward)
	run_stats.set_gold(run_stats.gold + level)
	_finish(dish_button.get_pressed_desc(0 if level <= 3 else 1))


func _taste_food() -> void:
	var run: Run = _get_run()
	if run == null or run.player_build_proxy == null:
		return
	var controller: StatsController = run.player_build_proxy.get_stats_controller()
	if controller == null:
		return
	var maximum: float = controller.get_stat(&"max_health")
	var current: float = run_stats.player_build.current_health
	var restored: float = min(current + maximum * 0.5, maximum)
	run_stats.player_build.current_health = restored
	controller.current_health = restored
	controller.sync_runtime_resources()
	EventBus.player_health_changed.emit(restored, maximum)
	run_stats.pending_battle_all_primary_stats_bonus += 1
	_finish(taste_button.get_pressed_desc())


func _find_inventory_slots(tag_name: String) -> Array[Slot]:
	var result: Array[Slot] = []
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_inventory == null:
		return result
	for slot: Slot in run_stats.player_build.player_inventory.slots:
		if slot != null and slot.item != null and _has_tag(slot.item, tag_name):
			result.append(slot)
	return result


func _find_exchangeable_ingredients() -> Array[Slot]:
	var result: Array[Slot] = []
	for slot: Slot in _find_inventory_slots("原料"):
		if not _get_relics(slot.item.level, "佳肴").is_empty():
			result.append(slot)
	return result


func _get_relics(level: int, tag_name: String = "") -> Array[Relic]:
	var result: Array[Relic] = []
	for relic: Relic in RELIC_POOL.get_relics_by_level(level):
		if tag_name.is_empty() or _has_tag(relic, tag_name):
			result.append(relic)
	return result


func _has_tag(relic: Relic, tag_name: String) -> bool:
	for tag: RelicTag in relic.tags:
		if tag != null and tag.tag_name == tag_name:
			return true
	return false


func _free_inventory_slots() -> int:
	var count: int = 0
	for slot: Slot in run_stats.player_build.player_inventory.slots:
		if slot == null or slot.item == null:
			count += 1
	return count


func _finish(result_text: String) -> void:
	desc_label.text = result_text
	dish_picker.hide()
	for button: EventRoomButton in [ingredient_button, dish_button, taste_button]:
		button.queue_free()
	var run: Run = _get_run()
	if run != null and run.player_build_proxy != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


func _get_run() -> Run:
	var node: Node = get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
