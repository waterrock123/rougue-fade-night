class_name ShopLevelData
extends Resource

#level指商店升到level等级时会触发的effects
@export var level: int
@export var upgrade_cost: int
@export var effects: Array[ShopEffect]
