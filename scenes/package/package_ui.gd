class_name  PackageUI
extends Control

@onready var bag_slot_container: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/BagSlotContainer
@onready var relic_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/RelicContainer


@onready var bag_slots: Array = $PanelContainer/MarginContainer/VBoxContainer/BagSlotContainer.get_children()


var bag_inventory: Inventory
@onready var relic_ui_instance = preload("res://scenes/relic/relic_ui.tscn")

func _ready() -> void:
	close_bag()



func set_player_inventory(player_inventory:Inventory):
	#把外部传入的玩家专属库存赋值给当前背包
	bag_inventory = player_inventory
	
	if bag_inventory:
		bag_update()


func open_bag(player_inventroy:Inventory):
	set_player_inventory(player_inventroy)
	show()
	
func close_bag():
	hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_E:
		visible = !visible





#背包更新核心函数：把库存数据同步到UI格子上
func bag_update():
	if bag_inventory.slots.size() != bag_slots.size():
		return
	#检查当前库存格子是否为空
	for i in range(bag_slots.size()):
		var inventory_slots: Slot = bag_inventory.slots[i] 
	
		if !inventory_slots:
			
			if bag_slots[i].slot_button_slot_relic:
				bag_slots[i].slot_button_slot_relic.queue_free()
				#把UI格子里的物品节点设为null
				bag_slots[i].slot_button_slot_relic = null
			bag_slots[i].reset_color()
			continue
		#再检查当前库存格子里是否物品
		if !inventory_slots.item:
			
			if bag_slots[i].slot_button_slot_relic:
				bag_slots[i].slot_button_slot_relic.queue_free()
				bag_slots[i].slot_button_slot_relic = null
			bag_slots[i].reset_color()
			continue
		#获取当前UI格子里的物品显示节点（relic_ui）
		var relic_ui:RelicUI = bag_slots[i].slot_button_slot_relic
		
		#如果UI格子里没有物品显示节点
		if !relic_ui:
			relic_ui = relic_ui_instance.instantiate()
			bag_slots[i].insert(relic_ui)#把实例化的物品显示节点插入
		#把库存格子的数据赋值给物品显示节点	
		relic_ui.slot_ = inventory_slots
		#调用物品显示节点的更新函数，让它显示物品图标和数量
		relic_ui.slot_relic_update()
