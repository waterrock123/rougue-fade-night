class_name MapTagTerrainSpawnModifier
extends Resource

## 地图特殊地形生成规则的修正数据。
## 当前会被 BattleMapTerrainRandomizer 读取，用于让玩家启用的地图标签影响特殊地形。

@export var terrain_id: StringName
## UI 展示时使用的关键词 id。留空时会直接使用 terrain_id。
@export var display_keyword_id: StringName
@export_range(-1.0, 1.0, 0.01) var chance_bonus: float = 0.0
@export var chance_multiplier: float = 1.0
@export var flat_count_bonus: int = 0
## 当前按“生成格子数量倍率”处理；以后如果做连续区域扩张，可以再扩展成真正的范围缩放。
@export var area_multiplier: float = 1.0
## 分布倾向：负数更集中，正数更分散，0 表示保持原样。
@export_range(-1.0, 1.0, 0.01) var distribution_bias: float = 0.0
@export_multiline var summary: String = ""


func get_summary() -> String:
	if not summary.is_empty():
		return summary

	var parts: Array[String] = []
	if terrain_id != &"":
		parts.append("影响地形：%s" % String(terrain_id))
	if display_keyword_id != &"":
		parts.append("显示关键词：%s" % String(display_keyword_id))
	if chance_bonus != 0.0:
		parts.append("概率修正：%.0f%%" % (chance_bonus * 100.0))
	if chance_multiplier != 1.0:
		parts.append("概率倍率：%.2f" % chance_multiplier)
	if flat_count_bonus != 0:
		parts.append("数量修正：%d" % flat_count_bonus)
	if area_multiplier != 1.0:
		parts.append("数量倍率：%.2f" % area_multiplier)
	if distribution_bias != 0.0:
		parts.append("分布倾向：%.2f" % distribution_bias)

	return "，".join(parts)
