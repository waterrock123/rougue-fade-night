class_name TagEffectDatabase
extends Resource

const USER_SELECTION_PATH := "user://tag_effect_selection.json"

@export var effects: Array[TagEffect] = []
## 如果资源里的 effects 列表被编辑器重存丢失，就从这些文件夹自动扫描 TagEffect 资源兜底。
@export var effect_folders: Array[String] = ["res://tag_effects"]
## 默认选中的效果。玩家还没设置时使用。
@export var default_selected_effects: Array[TagEffect] = []

var selected_effect_by_tag: Dictionary = {}


# 读取玩家本地选择；没有本地选择时回退到资源中配置的默认选择。
func load_selection() -> void:
	_ensure_effects_loaded()
	selected_effect_by_tag.clear()

	var loaded := _load_user_selection()
	if not loaded.is_empty():
		selected_effect_by_tag = loaded
		return

	for effect in default_selected_effects:
		if effect == null or effect.tag == null:
			continue
		selected_effect_by_tag[effect.get_tag_key()] = effect.id


# 保存某个 tag 当前启用的效果。
func select_effect(effect: TagEffect) -> void:
	if effect == null or effect.tag == null:
		return

	selected_effect_by_tag[effect.get_tag_key()] = effect.id
	save_selection()


func get_all_tags() -> Array[RelicTag]:
	_ensure_effects_loaded()
	var result: Array[RelicTag] = []
	var used_keys: Array[String] = []

	for effect in effects:
		if effect == null or effect.tag == null:
			continue
		var tag_key := effect.get_tag_key()
		if used_keys.has(tag_key):
			continue

		used_keys.append(tag_key)
		result.append(effect.tag)

	return result


func get_effects_for_tag(tag: RelicTag) -> Array[TagEffect]:
	_ensure_effects_loaded()
	var result: Array[TagEffect] = []
	var tag_key := _get_tag_key(tag)
	if tag_key.is_empty():
		return result

	for effect in effects:
		if effect == null:
			continue
		if effect.get_tag_key() == tag_key:
			result.append(effect)

	result.sort_custom(func(a: TagEffect, b: TagEffect) -> bool:
		return a.required_count < b.required_count
	)
	return result


func get_selected_effect_for_tag(tag: RelicTag) -> TagEffect:
	var tag_key := _get_tag_key(tag)
	if tag_key.is_empty():
		return null

	var selected_id := StringName(selected_effect_by_tag.get(tag_key, &""))
	for effect in get_effects_for_tag(tag):
		if effect.id == selected_id:
			return effect

	var tag_effects := get_effects_for_tag(tag)
	return tag_effects[0] if not tag_effects.is_empty() else null


func get_selected_effects() -> Array[TagEffect]:
	_ensure_effects_loaded()
	var result: Array[TagEffect] = []
	for tag in get_all_tags():
		var effect := get_selected_effect_for_tag(tag)
		if effect != null:
			result.append(effect)
	return result


func save_selection() -> void:
	var data := {}
	for tag_key in selected_effect_by_tag.keys():
		data[str(tag_key)] = str(selected_effect_by_tag[tag_key])

	var file := FileAccess.open(USER_SELECTION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法保存 tag 效果选择：%s" % USER_SELECTION_PATH)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _load_user_selection() -> Dictionary:
	if not FileAccess.file_exists(USER_SELECTION_PATH):
		return {}

	var file := FileAccess.open(USER_SELECTION_PATH, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}

	var result := {}
	for tag_key in (parsed as Dictionary).keys():
		result[str(tag_key)] = StringName(str((parsed as Dictionary)[tag_key]))
	return result


func _get_tag_key(tag: RelicTag) -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name


func _ensure_effects_loaded() -> void:
	if not effects.is_empty():
		return

	var discovered_effects: Array[TagEffect] = []
	for folder in effect_folders:
		_collect_effects_from_folder(str(folder), discovered_effects)

	effects = discovered_effects


func _collect_effects_from_folder(folder_path: String, result: Array[TagEffect]) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var child_path := folder_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_effects_from_folder(child_path, result)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var loaded := load(child_path)
			if loaded is TagEffect:
				result.append(loaded as TagEffect)

		file_name = dir.get_next()
