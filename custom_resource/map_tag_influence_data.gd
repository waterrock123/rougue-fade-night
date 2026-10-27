class_name MapTagInfluenceData
extends Resource

## 一个标签对战斗地图生成的影响数据。
## UI 会展示它，RunStats 会保存玩家是否启用它，地图生成器会读取它来修正特殊物体与特殊地形。

@export var enabled: bool = true
@export var tag: RelicTag
@export var display_name_override: String = ""
@export_multiline var summary: String = ""
## 某些规则只需一句说明，例如固定出现一个状态箱，不展示内部概率修正。
@export var summary_replaces_modifiers: bool = false
## 地图特殊物体修正，例如苹果树、动物、剑座、弹药箱。
@export var object_spawn_modifiers: Array[MapTagObjectSpawnModifier] = []
## 地图特殊地形修正，例如火海、冰面、雷暴区域。
@export var terrain_spawn_modifiers: Array[MapTagTerrainSpawnModifier] = []
## 拾取、道路移动、摧毁奖励等战斗内规则。
@export var runtime_modifiers: Array[MapTagRuntimeModifier] = []
@export var future_terrain_notes: Array[String] = []


func get_tag_key() -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name


## 只放大标签带来的增量，不放大地图的基础概率；复制资源以免污染所有角色共用的数据库。
func scaled_copy(strength: float) -> MapTagInfluenceData:
	var result: MapTagInfluenceData = duplicate(true) as MapTagInfluenceData
	var factor: float = maxf(strength, 0.0)
	for modifier: MapTagRuntimeModifier in result.runtime_modifiers:
		if modifier != null:
			modifier.amount *= factor
	for modifier: MapTagObjectSpawnModifier in result.object_spawn_modifiers:
		if modifier == null:
			continue
		modifier.chance_bonus *= factor
		modifier.flat_min_count_bonus = int(roundf(modifier.flat_min_count_bonus * factor))
		modifier.flat_max_count_bonus = int(roundf(modifier.flat_max_count_bonus * factor))
		modifier.count_bonus_per_tag_stack *= factor
		modifier.weight_bonus *= factor
		modifier.weight_bonus_per_tag_stack *= factor
	for modifier: MapTagTerrainSpawnModifier in result.terrain_spawn_modifiers:
		if modifier == null:
			continue
		modifier.chance_bonus *= factor
		modifier.chance_multiplier = maxf(1.0 + (modifier.chance_multiplier - 1.0) * factor, 0.0)
		modifier.flat_count_bonus = int(roundf(modifier.flat_count_bonus * factor))
		modifier.area_multiplier = maxf(1.0 + (modifier.area_multiplier - 1.0) * factor, 0.0)
		modifier.distribution_bias = clampf(modifier.distribution_bias * factor, -1.0, 1.0)
	return result


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
	for modifier: MapTagRuntimeModifier in runtime_modifiers:
		if modifier != null:
			result.append(modifier.get_summary())

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
