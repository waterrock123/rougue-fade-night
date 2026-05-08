class_name Character
extends Resource

@export_group("视觉资源")
@export var character_name:String
@export_multiline var description: String
@export var background:Texture


@export_group("游戏资源")
@export var start_stats:StatsData
# 兼容旧配置：如果只配置一个起始技能，也会在开局时加入玩家构筑。
@export var start_skill:SkillEntry
# 新配置：角色可以拥有多个起始技能，主动/被动会在创建 PlayerBuild 时自动分流。
@export var start_skills:Array[SkillEntry] = []
@export var start_inventory:Inventory
@export var start_equipment:Equipment
@export var start_shop:Shop
@export var start_shop_config:ShopConfig
@export var shop_keeper_pool:Array[ShopKeeper]
@export var main_attributes: Array[StringName] = []
