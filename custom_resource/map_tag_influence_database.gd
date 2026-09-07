class_name MapTagInfluenceDatabase
extends Resource

## 地图标签影响数据库。
## 后续“标签配置界面”和“地图生成器”都应读取这份数据库，而不是各自硬编码标签效果。

@export var influences: Array[MapTagInfluenceData] = []

var _influence_by_tag_key: Dictionary = {}


func get_influence_for_tag(tag: RelicTag) -> MapTagInfluenceData:
	return get_influence_for_tag_key(get_tag_key(tag))


func get_influence_for_tag_key(tag_key: String) -> MapTagInfluenceData:
	_rebuild_cache_if_needed()
	return _influence_by_tag_key.get(tag_key, null) as MapTagInfluenceData


func get_influences_for_tag_keys(tag_keys: Array[String]) -> Array[MapTagInfluenceData]:
	var result: Array[MapTagInfluenceData] = []
	for tag_key: String in tag_keys:
		var influence: MapTagInfluenceData = get_influence_for_tag_key(tag_key)
		if influence == null or not influence.enabled:
			continue
		result.append(influence)
	return result


func get_summary_lines_for_tag_keys(tag_keys: Array[String], tag_counts: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	for influence: MapTagInfluenceData in get_influences_for_tag_keys(tag_keys):
		var tag_key: String = influence.get_tag_key()
		var tag_count: int = int(tag_counts.get(tag_key, 0))
		var lines: Array[String] = influence.get_summary_lines(tag_count)
		if lines.is_empty():
			continue
		result.append("%s：%s" % [influence.get_display_name(), "；".join(lines)])
	return result


func clear_cache() -> void:
	_influence_by_tag_key.clear()


func get_tag_key(tag: RelicTag) -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name


func _rebuild_cache_if_needed() -> void:
	if not _influence_by_tag_key.is_empty():
		return

	for influence: MapTagInfluenceData in influences:
		if influence == null:
			continue
		var tag_key: String = influence.get_tag_key()
		if tag_key.is_empty():
			continue
		_influence_by_tag_key[tag_key] = influence
