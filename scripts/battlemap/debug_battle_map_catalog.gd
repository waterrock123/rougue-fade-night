@tool
class_name DebugBattleMapCatalog
extends RefCounted
## 调试地图目录。只读取PackedScene的根脚本与工坊元数据，绝不实例化整张地图。

const ROOT_PATH: String = "res://scenes/battlemap/templates"


static func collect_paths(folder: String = ROOT_PATH) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return result
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() == "tscn":
			result.append(folder.path_join(file))
	for directory: String in DirAccess.get_directories_at(folder):
		if not directory.begins_with("."):
			result.append_array(collect_paths(folder.path_join(directory)))
	result.sort()
	return result


static func read_info(path: String) -> Dictionary:
	var clean_path: String = path.strip_edges()
	if not clean_path.begins_with("res://") or clean_path.contains("..") or not ResourceLoader.exists(clean_path, "PackedScene"):
		return {}
	var packed: PackedScene = ResourceLoader.load(clean_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return {}
	var state: SceneState = packed.get_state()
	var script: Script = _root_property(state, &"script") as Script
	var is_battle_map: bool = false
	while script != null:
		if script.get_global_name() == &"BattleMap":
			is_battle_map = true
			break
		script = script.get_base_script()
	if not is_battle_map:
		return {}
	var label: String = clean_path.get_file().get_basename()
	var preset: Resource = _root_property(state, &"metadata/map_workshop_settings") as Resource
	if preset != null and preset.get_script() != null and preset.get_script().get_global_name() == &"BattleMapDraftSettings":
		label += " [工坊·种子%s]" % str(preset.get("seed_value"))
	return {"path": clean_path, "label": label}


static func is_battle_map(path: String) -> bool:
	return not read_info(path).is_empty()


static func _root_property(state: SceneState, property_name: StringName) -> Variant:
	while state != null:
		if state.get_node_count() > 0:
			for index: int in range(state.get_node_property_count(0)):
				if state.get_node_property_name(0, index) == property_name:
					return state.get_node_property_value(0, index)
		state = state.get_base_scene_state()
	return null
