class_name MapObjectDatabase
extends Resource

## 地图物件生成数据库。
## ObjectSpawnerFromTileMap 只负责读取 object_id；具体生成哪个场景由这个资源决定。

@export var entries: Array[MapObjectEntry] = []

var entry_map: Dictionary = {}


func get_entry(object_id: StringName) -> MapObjectEntry:
	_ensure_entry_map()
	return entry_map.get(object_id) as MapObjectEntry


func get_scene(object_id: StringName) -> PackedScene:
	var entry: MapObjectEntry = get_entry(object_id)
	if entry == null:
		return null
	return entry.scene


func has_object(object_id: StringName) -> bool:
	return get_entry(object_id) != null


## 编辑器里修改 entries 后，如果运行中要重新读取，可以手动清掉缓存。
func clear_cache() -> void:
	entry_map.clear()


func _ensure_entry_map() -> void:
	if not entry_map.is_empty():
		return

	for entry: MapObjectEntry in entries:
		if entry == null or not entry.is_valid_entry():
			continue
		if entry_map.has(entry.object_id):
			push_warning("MapObjectDatabase 存在重复 object_id：%s，后面的配置会覆盖前面的配置。" % String(entry.object_id))
		entry_map[entry.object_id] = entry
