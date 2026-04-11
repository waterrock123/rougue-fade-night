class_name  PackageUI
extends Control

@onready var bag_slot_container: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/BagSlotContainer
@onready var relic_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/RelicContainer


@onready var bag_slots: Array = $PanelContainer/MarginContainer/VBoxContainer/BagSlotContainer.get_children()
@onready var equipment_slots: Array = $PanelContainer/MarginContainer/VBoxContainer/RelicContainer.get_children()
#背包的库存数据
@export var bag_inventory: Inventory

#装备栏的数据
@export var  equipment_inventory: Equipment
@onready var relic_ui_instance = preload("res://scenes/relic/relic_ui.tscn")

var mouse_relic: RelicUI = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	connect_signal()
	close_bag()
	
	for i in range(bag_slots.size()):
		#获取当前库存的各个格子
		var slot = bag_slots[i]
		slot.slot_index = i
	
	for i in range(equipment_slots.size()):
		#获取当前装备的各个格子
		var slot_ = equipment_slots[i]
		slot_.slot_index = i


func set_player_equipment(player_equipment:Equipment):
	equipment_inventory = player_equipment
	if equipment_inventory:
		equipment_update()


func set_player_inventory(player_inventory:Inventory):
	#把外部传入的玩家专属库存赋值给当前背包
	bag_inventory = player_inventory
	
	if bag_inventory:
		bag_update()

func connect_signal():
	for slot_button in bag_slots:
		slot_button.mouse_button_left_press.connect(on_mouse_left_slot_button.bind(slot_button))
	for equipment_button in equipment_slots:
		equipment_button.mouse_button_left_press.connect(on_mouse_left_slot_button.bind(equipment_button))
		
		


func open_bag(player_inventroy:Inventory,player_equipment:Equipment):
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
	for equp_button in equipment_slots:
		equp_button.equipment_inventory =equipment_inventory
	
	show()
	
func close_bag():
	hide()

func _input(event: InputEvent) -> void:
	relic_follow_mouse()




#装备更新函数:把装备库存数据同步到UI格子上去
func equipment_update():
	if equipment_inventory.equip_slots.size() != equipment_slots.size():
		return
	#检查当前库存格子是否为空
	for i in range(equipment_slots.size()):
		var equipment_slot: Slot = equipment_inventory.equip_slots[i] 
	
		if !equipment_slot:
			equipment_slots[i].reset_color()
			continue
		#再检查当前库存格子里是否物品
		if !equipment_slot.item:
			
			
			continue
		#获取当前UI格子里的物品显示节点（relic_ui）
		var relic_ui:RelicUI = equipment_slots[i].slot_button_slot_relic
		
		#如果UI格子里没有物品显示节点
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			equipment_slots[i].insert(relic_ui)#把实例化的物品显示节点插入
		#把库存格子的数据赋值给物品显示节点	
		relic_ui.slot_ = equipment_slot
		#调用物品显示节点的更新函数，让它显示物品图标和数量
		relic_ui.slot_relic_update()


#背包更新核心函数：把库存数据同步到UI格子上
func bag_update():
	if bag_inventory.slots.size() != bag_slots.size():
		return
	#检查当前库存格子是否为空
	for i in range(bag_slots.size()):
		var inventory_slot: Slot = bag_inventory.slots[i] 
	
		if !inventory_slot:
			
			#if bag_slots[i].slot_button_slot_relic:
				#bag_slots[i].slot_button_slot_relic.queue_free()
				##把UI格子里的物品节点设为null
				#bag_slots[i].slot_button_slot_relic = null
			bag_slots[i].reset_color()
			continue
		#再检查当前库存格子里是否物品
		if !inventory_slot.item:
			
			#if bag_slots[i].slot_button_slot_relic:
				#bag_slots[i].slot_button_slot_relic.queue_free()
				#bag_slots[i].slot_button_slot_relic = null
			#bag_slots[i].reset_color()
			continue
		#获取当前UI格子里的物品显示节点（relic_ui）
		var relic_ui:RelicUI = bag_slots[i].slot_button_slot_relic
		
		#如果UI格子里没有物品显示节点
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			bag_slots[i].insert(relic_ui)#把实例化的物品显示节点插入
		#把库存格子的数据赋值给物品显示节点	
		relic_ui.slot_ = inventory_slot
		#调用物品显示节点的更新函数，让它显示物品图标和数量
		relic_ui.slot_relic_update()

func on_mouse_left_slot_button(slot_button):
	#情况一，点击的格子为空，且有正在跟随鼠标物品
	if slot_button.is_empty() and  mouse_relic:
		insert_relic_in_slot(slot_button)
	
	#情况二,点击的格子有物品，且没有正在跟随鼠标的物品（准备抓取物品）
	elif !slot_button.is_empty() and !mouse_relic:
		take_relic_from_slot(slot_button)
		
	#情况三，点击的格子有物品，且鼠标上正跟随有物品
	elif !slot_button.is_empty() and mouse_relic:
		print("有执行交换")
		#目标格子里的物品id
		var slot_relic_id = slot_button.slot_button_slot_relic.slot_.item.id
		#鼠标上格子里的物品id
		var mouse_relic_id = mouse_relic.relic.id
		if slot_relic_id != mouse_relic_id:
			print("有调用交换函数")
			#交换函数，实现两个物品互换
			swap_relic(slot_button)

#从格子抓取物品，控制物品跟随鼠标
func take_relic_from_slot(slot_button):
	#将当前格子的物品赋值给moouse_item
	mouse_relic = slot_button.take_relic()
	#把抓取的物品添加为当前bag_ui的子节点（让物品显示在背包上层，不被遮挡）
	add_child(mouse_relic)
	relic_follow_mouse()

#放入物品函数
func insert_relic_in_slot(slot_button):
	#临时记录鼠标上的物品
	var relic_ = mouse_relic
	
	#让物品不再跟随鼠标
	remove_child(mouse_relic)
	
	#重置鼠标物品状态
	mouse_relic = null
	
	
	#调用当前格子的insert函数，把物品放入格子
	slot_button.insert(relic_)


func swap_relic(slot_button:SlotButton):
	#临时变量:用于储存格子里的物品
	var one_relic = slot_button.take_relic()
	
	
	#调用函数把鼠标上的物品放入格子中
	insert_relic_in_slot(slot_button)
	#把临时储存物品赋值鼠标的物品
	mouse_relic = one_relic
	
	add_child(mouse_relic)
	relic_follow_mouse()


func relic_follow_mouse():
	#如果没有鼠标跟随，直接返回
	if !mouse_relic:
		return
	
	mouse_relic.global_position = get_global_mouse_position()
	

	
