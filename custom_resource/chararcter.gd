class_name Character
extends Resource

@export_group("视觉资源")
@export var character_name:String
@export_multiline var description: String
@export var background:Texture


@export_group("游戏资源")
@export var start_stats:StatsData
@export var start_inventory:Inventory
@export var start_equipment:Equipment
@export var start_shop:Shop
@export var start_shop_config:ShopConfig
@export var shop_keeper_pool:Array[ShopKeeper]
