class_name Shop
extends Resource
#用来储存商店当前状态的类

#商店的当前等级
@export var level:int = 1
#商店的当前出售格子
@export var slot_count:int = 4
#当前商店的格子
@export var current_slot:Array[Slot]
#当前商店的商人
@export var shopkeeper:ShopKeeper
