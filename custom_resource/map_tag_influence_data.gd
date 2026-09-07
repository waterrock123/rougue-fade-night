class_name MapTagInfluenceData
extends Resource

## 一个标签对战斗地图生成的影响数据。
## UI 会展示它，RunStats 会保存玩家是否启用它，地图生成器会读取它来修正特殊物体与特殊地形。

@export var enabled: bool = true
@export var tag: RelicTag
@export var display_name_override: String = ""
@export_multiline var summary: String = ""
## 地图特殊物体修正，例如苹果树、动物、剑座、弹药箱。
@export var object_spawn_modifiers: Array[MapTagObjectSpawnModifier] = []
## 地图特殊地形修正，例如火海、冰面、雷暴区域。
@export var terrain_spawn_modifiers: Array[MapTagTerrainSpawnModifier] = []
@export var future_terrain_notes: Array[String] = []


func get_tag_key() -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name


func get_display_name() -> String:
	if not display_name_override.is_empty():
		return display_name_override
	if tag != null:
		return tag.tag_name
	return "未设置标签"


func get_tag_color() -> Color:
	if tag == null:
		return Color.WHITE
	return tag.color


func get_summary_lines(tag_count: int = 0) -> Array[String]:
	var result: Array[String] = []
	if not summary.is_empty():
		result.append(summary)

	for modifier: MapTagObjectSpawnModifier in object_spawn_modifiers:
		if modifier == null:
			continue
		var modifier_summary: String = modifier.get_summary(tag_count)
		if not modifier_summary.is_empty():
			result.append(modifier_summary)

	for modifier: MapTagTerrainSpawnModifier in terrain_spawn_modifiers:
		if modifier == null:
			continue
		var terrain_summary: String = modifier.get_summary()
		if not terrain_summary.is_empty():
			result.append(terrain_summary)

	for note: String in future_terrain_notes:
		if note.is_empty():
			continue
		result.append(note)

	return result
