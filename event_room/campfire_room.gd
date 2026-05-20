class_name CampfireRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "campfire_room_event_buttons"
const RESTORE_HEALTH_RATE := 0.3
const LEVEL_UP_REFRESH_REWARD := 1

@onready var sleep_button: EventRoomButton = $SleepButton
@onready var sharp_button: EventRoomButton = $SharpButton
@onready var ability_button: EventRoomButton = $AbilityButton
@onready var desc_label: Label = $DescLabel


# 进入营火房时绑定三个选项的效果，并根据当前构筑刷新按钮可用状态。
func setup() -> void:
	_setup_event_button(sleep_button, _choose_sleep)
	_setup_event_button(sharp_button, _choose_sharpen_relic)
	_setup_event_button(ability_button, _choose_training)
	_refresh_button_availability()


# 统一初始化事件按钮，保持和其他事件房间一致的“按钮只负责回调”的结构。
func _setup_event_button(button: EventRoomButton, callback: Callable) -> void:
	if button == null:
		return

	button.add_to_group(EVENT_BUTTON_GROUP)
	button.setup_button(callback)


# 继续休息：回复最大生命值 30%。
func _choose_sleep() -> void:
	var restored_amount := _restore_health_by_rate(RESTORE_HEALTH_RATE)
	if restored_amount > 0.0:
		_resolve_choice(sleep_button, 0)
	else:
		_set_desc_text("你已经休息得足够充分，身体没有更多可恢复的伤势。")
		_clear_event_buttons()


# 与装备同调：随机把背包或装备栏里一件未升级装备改为升级态。
func _choose_sharpen_relic() -> void:
	var relic := _upgrade_random_player_relic()
	if relic != null:
		_resolve_choice(sharp_button, 0)
	else:
		_set_desc_text("你翻遍了背包，却没有找到适合同调的未升级装备。")
		_clear_event_buttons()


# 磨炼技艺：获得一次升级奖励刷新次数。
func _choose_training() -> void:
	if run_stats != null:
		run_stats.add_level_up_reward_refresh_count(LEVEL_UP_REFRESH_REWARD)

	_resolve_choice(ability_button, 0)


func _resolve_choice(button: EventRoomButton, desc_index: int = 0) -> void:
	if button != null:
		_set_desc_text(button.get_pressed_desc(desc_index))

	_clear_event_buttons()
	_sync_run_after_choice()


func _clear_event_buttons() -> void:
	for node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _restore_health_by_rate(rate: float) -> float:
	var stats_controller := _get_runtime_stats_controller()
	if run_stats == null or run_stats.player_build == null or stats_controller == null:
		return 0.0

	var max_health := stats_controller.get_stat(&"max_health")
	if max_health <= 0.0:
		return 0.0

	var current_health := run_stats.player_build.current_health
	if current_health <= 0.0:
		current_health = stats_controller.current_health

	var heal_amount = max_health * clamp(rate, 0.0, 1.0)
	var new_health = min(current_health + heal_amount, max_health)
	var restored_amount = max(new_health - current_health, 0.0)
	if restored_amount <= 0.0:
		return 0.0

	run_stats.player_build.current_health = new_health
	stats_controller.current_health = new_health
	stats_controller.sync_runtime_resources()
	EventBus.player_health_changed.emit(new_health, max_health)
	return restored_amount


func _upgrade_random_player_relic() -> Relic:
	var candidates := _get_unlevelup_player_relic_slots()
	if candidates.is_empty():
		return null

	var selected_slot := RunRng.pick(candidates) as Slot
	if selected_slot == null or selected_slot.item == null:
		return null

	selected_slot.item.leveltip = Relic.LevelTip.LEVELUP
	AudioController.play_ui_sound(&"level_up_item")
	EventBus.inventory_update.emit()
	EventBus.equipment_update.emit()
	return selected_slot.item


# 检查背包栏和装备栏；营火同调可以直接强化玩家已经穿戴的装备。
func _get_unlevelup_player_relic_slots() -> Array[Slot]:
	var result: Array[Slot] = []
	if run_stats == null or run_stats.player_build == null:
		return result

	_collect_unlevelup_slots(result, run_stats.player_build.player_equipment.equip_slots if run_stats.player_build.player_equipment != null else [])
	_collect_unlevelup_slots(result, run_stats.player_build.player_inventory.slots if run_stats.player_build.player_inventory != null else [])

	return result


func _collect_unlevelup_slots(result: Array[Slot], slots: Array) -> void:
	for slot in slots:
		if slot == null or slot.item == null:
			continue
		if slot.item.leveltip != Relic.LevelTip.UNLEVELUP:
			continue
		result.append(slot)


func _refresh_button_availability() -> void:
	if sharp_button != null and _get_unlevelup_player_relic_slots().is_empty():
		sharp_button.disabled = true
		sharp_button.detail_text = "没有未升级装备可同调"
		sharp_button.refresh_display()


func _set_desc_text(text: String) -> void:
	if desc_label != null:
		desc_label.text = text


func _sync_run_after_choice() -> void:
	var run := _get_run()
	if run == null:
		return

	if run.player_build_proxy != null and run_stats != null and run_stats.player_build != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


func _get_runtime_stats_controller() -> StatsController:
	var run := _get_run()
	if run != null and run.player_build_proxy != null:
		return run.player_build_proxy.get_stats_controller()
	return null


func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
