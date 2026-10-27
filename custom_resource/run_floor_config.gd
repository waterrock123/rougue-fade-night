## 一层路线地图的生成配置；只保存模板数据，不保存玩家进度。
class_name RunFloorConfig
extends Resource

@export var display_name: String = "草原"
@export_range(2, 20) var column_count: int = 6
## 留空时沿用 MapGenerator 上配置的战斗池。
@export var battle_pool: BattleStatsPool
## 普通房间按列取战斗等阶；超过数组长度时沿用最后一项。Boss 固定取 tier 3。
@export var normal_battle_tiers: Array[int] = [0, 0, 1, 1, 2]


func get_battle_tier(column_index: int, is_boss: bool) -> int:
	if is_boss:
		return 3
	if normal_battle_tiers.is_empty():
		return 0
	var index: int = clampi(column_index, 0, normal_battle_tiers.size() - 1)
	return clampi(normal_battle_tiers[index], 0, 2)
