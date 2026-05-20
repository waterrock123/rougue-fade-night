class_name Slot
extends Resource
#规定如果传入的格子里有遗物带有这个格子的limit_tag，那么将无法放入
@export var limit_tag: Array[String]

@export var item: Relic =null

# 锁住的背包格不会被玩家主动放入装备。
# 当普通格子已满时，获得的新装备可以临时进入锁格，离开修整期时会被清理。
@export var is_locked: bool = false
