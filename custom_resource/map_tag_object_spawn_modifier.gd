class_name MapTagObjectSpawnModifier
extends Resource

## 地图特殊物体生成规则的修正数据。
## 它可以按 object_id 精确匹配，也可以按 MapObjectEntry 的 feature_tags 影响一类物体。

const TARGET_MODE_OBJECT_ID: StringName = &"object_id"
const TARGET_MODE_FEATURE_TAG: StringName = &"feature_tag"
const TARGET_MODE_FEATURE_KIND: StringName = &"feature_kind"

@export_enum("object_id", "feature_tag", "feature_kind") var target_mode: String = String(TARGET_MODE_OBJECT_ID)
@export var object_id: StringName
@export_enum("special_object", "special_terrain") var target_feature_kind: String = String(MapObjectEntry.FEATURE_KIND_SPECIAL_OBJECT)
@export var feature_tags: Array[StringName] = []
@export var flat_min_count_bonus: int = 0
@export var flat_max_count_bonus: int = 0
@export var count_bonus_per_tag_stack: float = 0.0
@export var weight_bonus: float = 0.0
@export var weight_bonus_per_tag_stack: float = 0.0
@export_range(-1.0, 1.0, 0.01) var chance_bonus: float = 0.0
@export_multiline var summary: String = ""


func get_min_count_bonus(tag_count: int) -> int:
	return flat_min_count_bonus + int(floor(max(tag_count, 0) * count_bonus_per_tag_stack))


func get_max_count_bonus(tag_count: int) -> int:
	return flat_max_count_bonus + int(floor(max(tag_count, 0) * count_bonus_per_tag_stack))


func get_weight_bonus(tag_count: int) -> float:
	return weight_bonus + max(tag_count, 0) * weight_bonus_per_tag_stack


func matches_object(object_id_to_check: StringName, object_entry: MapObjectEntry) -> bool:
	var mode: StringName = StringName(target_mode)
	if mode == TARGET_MODE_OBJECT_ID:
		return object_id != &"" and object_id_to_check == object_id

	if object_entry == null:
		return false

	var expected_kind: StringName = StringName(target_feature_kind)
	if expected_kind != &"" and object_entry.get_feature_kind() != expected_kind:
		return false

	if mode == TARGET_MODE_FEATURE_KIND:
		return true
	if mode == TARGET_MODE_FEATURE_TAG:
		return _has_any_feature_tag(object_entry)

	return false


func get_summary(tag_count: int = 0) -> String:
	if not summary.is_empty():
		return summary

	var parts: Array[String] = []
	if StringName(target_mode) == TARGET_MODE_OBJECT_ID and object_id != &"":
		parts.append("影响物件：%s" % String(object_id))
	elif StringName(target_mode) == TARGET_MODE_FEATURE_TAG:
		parts.append("影响分类：%s" % _feature_tags_to_text())
	elif StringName(target_mode) == TARGET_MODE_FEATURE_KIND:
		parts.append("影响大类：%s" % target_feature_kind)
	if flat_min_count_bonus != 0 or flat_max_count_bonus != 0 or count_bonus_per_tag_stack != 0.0:
		parts.append("数量修正：%d ~ %d" % [get_min_count_bonus(tag_count), get_max_count_bonus(tag_count)])
	if weight_bonus != 0.0 or weight_bonus_per_tag_stack != 0.0:
		parts.append("权重修正：%.2f" % get_weight_bonus(tag_count))
	if chance_bonus != 0.0:
		parts.append("概率修正：%.0f%%" % (chance_bonus * 100.0))

	return "，".join(parts)


func _has_any_feature_tag(object_entry: MapObjectEntry) -> bool:
	for feature_tag: StringName in feature_tags:
		if object_entry.has_feature_tag(feature_tag):
			return true
	return false


func _feature_tags_to_text() -> String:
	var result: Array[String] = []
	for feature_tag: StringName in feature_tags:
		result.append(String(feature_tag))
	return " / ".join(result)
