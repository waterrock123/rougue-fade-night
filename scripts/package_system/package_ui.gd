class_name PackageUI
extends Control

@onready var bag_slot_container: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/BagSlotContainer
@onready var relic_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/RelicContainer

@onready var bag_slots: Array = $PanelContainer/MarginContainer/VBoxContainer/BagSlotContainer.get_children()
@onready var equipment_slots: Array = $PanelContainer/MarginContainer/VBoxContainer/RelicContainer.get_children()

# 背包库存数据
@export var bag_inventory: Inventory
# 装备栏数据
@export var equipment_inventory: Equipment
@onready var relic_ui_instance = preload("res://scenes/relic/relic_ui.tscn")

var mouse_relic: RelicUI = null
var mouse_relic_source_is_equipment := false
var equipment_locked := false
var sell_target: Control
var run_stats: RunStats


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	connect_signal()
	close_bag()

	for i in range(bag_slots.size()):
		var slot_button = bag_slots[i]
		slot_button.slot_index = i

	for i in range(equipment_slots.size()):
		var equipment_button = equipment_slots[i]
		equipment_button.slot_index = i


func set_player_equipment(player_equipment: Equipment):
	equipment_inventory = player_equipment
	if equipment_inventory:
		equipment_update()


func set_player_inventory(player_inventory: Inventory):
	bag_inventory = player_inventory
	if bag_inventory:
		bag_update()


# 连接背包和装备栏按钮的左右键信号。
func connect_signal():
	for slot_button in bag_slots:
		slot_button.mouse_button_left_press.connect(on_mouse_left_slot_button.bind(slot_button))
		slot_button.mouse_button_right_press.connect(on_mouse_right_bag_slot_button.bind(slot_button))

	for equipment_button in equipment_slots:
		equipment_button.mouse_button_left_press.connect(on_mouse_left_slot_button.bind(equipment_button))
		equipment_button.mouse_button_right_press.connect(on_mouse_right_equipment_slot_button.bind(equipment_button))


func open_bag(player_inventroy: Inventory, player_equipment: Equipment):
	set_player_inventory(player_inventroy)
	set_player_equipment(player_equipment)

	if bag_inventory == null or equipment_inventory == null:
		return

	if EventBus.equipment_update.is_connected(equipment_update):
		EventBus.equipment_update.disconnect(equipment_update)
	EventBus.equipment_update.connect(equipment_update)

	if EventBus.inventory_update.is_connected(bag_update):
		EventBus.inventory_update.disconnect(bag_update)
	EventBus.inventory_update.connect(bag_update)

	for slot_button in bag_slots:
		slot_button.slot_inventory = bag_inventory

	for equipment_button in equipment_slots:
		equipment_button.equipment_inventory = equipment_inventory

	show()


func close_bag():
	hide()


func set_equipment_locked(locked: bool) -> void:
	equipment_locked = locked


func _input(event: InputEvent) -> void:
	relic_follow_mouse()
	_update_sell_preview()

	if mouse_relic != null and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_try_sell_mouse_relic()


func set_sell_context(new_run_stats: RunStats, new_sell_target: Control) -> void:
	run_stats = new_run_stats
	sell_target = new_sell_target


# 把装备栏库存数据同步到 UI。
func equipment_update():
	if equipment_inventory == null:
		return

	if equipment_inventory.equip_slots.size() != equipment_slots.size():
		return

	for i in range(equipment_slots.size()):
		var equipment_slot: Slot = equipment_inventory.equip_slots[i]
		if !equipment_slot:
			_clear_slot_button(equipment_slots[i])
			continue

		if !equipment_slot.item:
			_clear_slot_button(equipment_slots[i])
			continue

		var relic_ui: RelicUI = equipment_slots[i].slot_button_slot_relic
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			equipment_slots[i].insert(relic_ui)

		relic_ui.slot_ = equipment_slot
		relic_ui.slot_relic_update()


# 把背包库存数据同步到 UI。
func bag_update():
	if bag_inventory == null:
		return

	if bag_inventory.slots.size() != bag_slots.size():
		return

	for i in range(bag_slots.size()):
		var inventory_slot: Slot = bag_inventory.slots[i]
		if !inventory_slot:
			_clear_slot_button(bag_slots[i])
			continue

		if !inventory_slot.item:
			_clear_slot_button(bag_slots[i])
			continue

		var relic_ui: RelicUI = bag_slots[i].slot_button_slot_relic
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			bag_slots[i].insert(relic_ui)

		relic_ui.slot_ = inventory_slot
		relic_ui.slot_relic_update()


# 左键逻辑：维持原有拖拽、拾取和交换功能。
func on_mouse_left_slot_button(slot_button):
	if mouse_relic != null and _is_mouse_over_sell_target():
		_try_sell_mouse_relic()
		return

	if _is_equipment_operation_locked(slot_button):
		_show_screen_tip("处于战斗中，无法穿戴/卸下装备")
		return

	if slot_button.is_empty() and mouse_relic:
		if not _can_insert_mouse_relic_in_slot(slot_button):
			return
		insert_relic_in_slot(slot_button)
	elif !slot_button.is_empty() and !mouse_relic:
		take_relic_from_slot(slot_button)
	elif !slot_button.is_empty() and mouse_relic:
		var slot_relic_id = slot_button.slot_button_slot_relic.slot_.item.id
		var mouse_relic_id = mouse_relic.relic.id
		if slot_relic_id != mouse_relic_id:
			if not _can_insert_mouse_relic_in_slot(slot_button):
				return
			swap_relic(slot_button)


# 右键背包格子：自动装备到装备栏中索引最小的空位。
func on_mouse_right_bag_slot_button(slot_button):
	if mouse_relic or slot_button.is_empty():
		return
	if equipment_locked:
		_show_screen_tip("处于战斗中，无法穿戴/卸下装备")
		return

	var empty_equipment_slot = _find_first_empty_slot(equipment_slots)
	if empty_equipment_slot == null:
		return
	if not _can_equip_relic_to_slot(_get_slot_button_relic(slot_button), empty_equipment_slot):
		return

	var relic_ui = slot_button.take_relic()
	empty_equipment_slot.insert(relic_ui)


# 右键装备栏格子：自动卸装到背包中索引最小的空位。
func on_mouse_right_equipment_slot_button(slot_button):
	if mouse_relic or slot_button.is_empty():
		return
	if equipment_locked:
		_show_screen_tip("处于战斗中，无法穿戴/卸下装备")
		return

	var empty_bag_slot = _find_first_empty_slot(bag_slots)
	if empty_bag_slot == null:
		return

	var relic_ui = slot_button.take_relic()
	empty_bag_slot.insert(relic_ui)


# 查找一组格子中索引最小且为空的那个格子。
func _find_first_empty_slot(slots: Array):
	for slot_button in slots:
		if slot_button.is_empty():
			return slot_button

	return null


# 从格子中抓取物品，让它跟随鼠标。
func take_relic_from_slot(slot_button):
	mouse_relic_source_is_equipment = _is_equipment_slot_button(slot_button)
	mouse_relic = slot_button.take_relic()
	add_child(mouse_relic)
	relic_follow_mouse()


# 把鼠标上的物品放入目标格子。
func insert_relic_in_slot(slot_button):
	var relic_ = mouse_relic
	relic_.hide_sell_price()
	remove_child(mouse_relic)
	mouse_relic = null
	mouse_relic_source_is_equipment = false
	slot_button.insert(relic_)


# 交换目标格子中的物品和鼠标上的物品。
func swap_relic(slot_button):
	var one_relic = slot_button.take_relic()
	insert_relic_in_slot(slot_button)
	mouse_relic = one_relic
	mouse_relic_source_is_equipment = _is_equipment_slot_button(slot_button)
	add_child(mouse_relic)
	relic_follow_mouse()


# 让鼠标抓着的物品 UI 跟随鼠标位置。
func relic_follow_mouse():
	if !mouse_relic:
		return

	mouse_relic.global_position = get_global_mouse_position()


func _update_sell_preview() -> void:
	if mouse_relic == null:
		return

	var relic := mouse_relic.relic
	if relic == null:
		mouse_relic.hide_sell_price()
		return

	if _is_mouse_over_sell_target():
		mouse_relic.show_sell_price(relic.sell_price)
	else:
		mouse_relic.hide_sell_price()


func _try_sell_mouse_relic() -> bool:
	if mouse_relic == null or run_stats == null:
		return false
	if not _is_mouse_over_sell_target():
		return false

	var relic := mouse_relic.relic
	if relic == null:
		return false

	run_stats.set_gold(run_stats.gold + max(relic.sell_price, 0))
	AudioController.play_ui_sound(&"sell_item")
	EventBus.relic_sold.emit(relic)
	mouse_relic.hide_sell_price()
	remove_child(mouse_relic)
	mouse_relic.queue_free()
	mouse_relic = null
	mouse_relic_source_is_equipment = false
	return true


func _is_mouse_over_sell_target() -> bool:
	if sell_target == null or not is_instance_valid(sell_target) or not sell_target.visible:
		return false

	return sell_target.get_global_rect().has_point(get_global_mouse_position())


# 数据格为空时，不只重置颜色，也要移除旧 RelicUI，避免合成后画面残留旧装备。
func _clear_slot_button(slot_button) -> void:
	if slot_button == null:
		return

	if slot_button.slot_button_slot_relic != null:
		var relic_ui: RelicUI = slot_button.slot_button_slot_relic
		if relic_ui.get_parent() == slot_button.center_container:
			slot_button.center_container.remove_child(relic_ui)
			relic_ui.queue_free()
		slot_button.slot_button_slot_relic = null

	slot_button.reset_color()


func _is_equipment_operation_locked(slot_button) -> bool:
	if not equipment_locked:
		return false
	if mouse_relic != null:
		return mouse_relic_source_is_equipment or _is_equipment_slot_button(slot_button)
	return _is_equipment_slot_button(slot_button)


func _is_equipment_slot_button(slot_button) -> bool:
	return equipment_slots.has(slot_button)


func _get_slot_button_relic(slot_button) -> Relic:
	if slot_button == null or slot_button.slot_button_slot_relic == null:
		return null
	if slot_button.slot_button_slot_relic.slot_ == null:
		return null
	return slot_button.slot_button_slot_relic.slot_.item


func _can_insert_mouse_relic_in_slot(slot_button) -> bool:
	if mouse_relic == null:
		return false
	if not _is_equipment_slot_button(slot_button):
		return true
	return _can_equip_relic_to_slot(mouse_relic.relic, slot_button)


func _can_equip_relic_to_slot(relic: Relic, target_equipment_slot) -> bool:
	if relic == null:
		return false
	if not relic.is_consumable:
		return true
	if not _has_other_equipped_consumable(target_equipment_slot):
		return true

	_show_screen_tip("只能装备一个消耗品")
	return false


func _has_other_equipped_consumable(excluded_equipment_slot = null) -> bool:
	for equipment_button in equipment_slots:
		if equipment_button == excluded_equipment_slot:
			continue
		var relic := _get_slot_button_relic(equipment_button)
		if relic != null and relic.is_consumable:
			return true

	return false


func _show_screen_tip(message: String) -> void:
	if FloatText != null and FloatText.has_method("show_screen_tip"):
		FloatText.show_screen_tip(message)
