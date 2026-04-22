class_name PlayerBuild
extends Resource


# 玩家构筑数据。
# 这份资源用于在战斗场景和修整期之间共享玩家当前的属性、背包和装备状态。
@export var player_stats: StatsData
@export var player_inventory: Inventory
@export var player_equipment: Equipment
@export var current_health: float = 0.0
@export var current_energy: float = 0.0
