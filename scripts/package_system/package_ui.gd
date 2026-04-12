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


func _input(event: InputEvent) -> void:
	relic_follow_mouse()


# 把装备栏库存数据同步到 UI。
func equipment_update():
	if equipment_inventory.equip_slots.size() != equipment_slots.size():
		return

	for i in range(equipment_slots.size()):
		var equipment_slot: Slot = equipment_inventory.equip_slots[i]
		if !equipment_slot:
			equipment_slots[i].reset_color()
			continue

		if !equipment_slot.item:
			equipment_slots[i].reset_color()
			continue

		var relic_ui: RelicUI = equipment_slots[i].slot_button_slot_relic
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			equipment_slots[i].insert(relic_ui)

		relic_ui.slot_ = equipment_slot
		relic_ui.slot_relic_update()


# 把背包库存数据同步到 UI。
func bag_update():
	if bag_inventory.slots.size() != bag_slots.size():
		return

	for i in range(bag_slots.size()):
		var inventory_slot: Slot = bag_inventory.slots[i]
		if !inventory_slot:
			bag_slots[i].reset_color()
			continue

		if !inventory_slot.item:
			bag_slots[i].reset_color()
			continue

		var relic_ui: RelicUI = bag_slots[i].slot_button_slot_relic
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			bag_slots[i].insert(relic_ui)

		relic_ui.slot_ = inventory_slot
		relic_ui.slot_relic_update()


# 左键逻辑：维持原有拖拽、拾取和交换功能。
func on_mouse_left_slot_button(slot_button):
	if slot_button.is_empty() and mouse_relic:
		insert_relic_in_slot(slot_button)
	elif !slot_button.is_empty() and !mouse_relic:
		take_relic_from_slot(slot_button)
	elif !slot_button.is_empty() and mouse_relic:
		var slot_relic_id = slot_button.slot_button_slot_relic.slot_.item.id
		var mouse_relic_id = mouse_relic.relic.id
		if slot_relic_id != mouse_relic_id:
			swap_relic(slot_button)


# 右键背包格子：自动装备到装备栏中索引最小的空位。
func on_mouse_right_bag_slot_button(slot_button):
	if mouse_relic or slot_button.is_empty():
		return

	var empty_equipment_slot = _find_first_empty_slot(equipment_slots)
	if empty_equipment_slot == null:
		return

	var relic_ui = slot_button.take_relic()
	empty_equipment_slot.insert(relic_ui)


# 右键装备栏格子：自动卸装到背包中索引最小的空位。
func on_mouse_right_equipment_slot_button(slot_button):
	if mouse_relic or slot_button.is_empty():
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
	mouse_relic = slot_button.take_relic()
	add_child(mouse_relic)
	relic_follow_mouse()


# 把鼠标上的物品放入目标格子。
func insert_relic_in_slot(slot_button):
	var relic_ = mouse_relic
	remove_child(mouse_relic)
	mouse_relic = null
	slot_button.insert(relic_)


# 交换目标格子中的物品和鼠标上的物品。
func swap_relic(slot_button):
	var one_relic = slot_button.take_relic()
	insert_relic_in_slot(slot_button)
	mouse_relic = one_relic
	add_child(mouse_relic)
	relic_follow_mouse()


# 让鼠标抓着的物品 UI 跟随鼠标位置。
func relic_follow_mouse():
	if !mouse_relic:
		return

	mouse_relic.global_position = get_global_mouse_position()
