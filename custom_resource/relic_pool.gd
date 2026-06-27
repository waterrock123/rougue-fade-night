class_name RelicPool
extends Resource

## 遗物池：商人只需要引用一个池子，再通过自身的偏好 tag、额外货物、禁售货物做差异化。
## relics 适合快速维护通用池；entries 适合给单个遗物配置权重或出现区间。
@export var relics: Array[Relic] = []
@export var entries: Array[RelicPoolEntry] = []

@export_group("Auto Collect")
@export var include_auto_collected_relics: bool = false
@export var auto_collect_folders: Array[String] = []
@export var auto_collect_recursive: bool = true
## 自动收集时跳过特殊/一次性遗物目录，避免测试资源或套装奖励误进入普通商店池。
@export var auto_collect_excluded_folders: Array[String] = ["res://relics/special"]

@export_group("Roll Weight")
@export var default_weight: float = 1.0

@export_group("Validation")
## 普通商店池默认只接受 1 级及以上遗物，level 0 通常代表未填写完成的占位资源。
@export var min_relic_level: int = 1
## 缺少基础展示信息的遗物会导致商店 tooltip 显示占位内容，因此默认不进入随机池。
@export var require_basic_info: bool = true
@export var require_icon: bool = true


func get_relics_up_to_level(shop_level: int) -> Array[Relic]:
	var result: Array[Relic] = []
	var seen: Dictionary = {}

	for entry: RelicPoolEntry in entries:
		if entry != null and entry.can_roll_up_to_shop_level(shop_level):
			_append_unique_relic(result, seen, entry.relic)

	for relic: Relic in relics:
		if relic != null and relic.level <= shop_level:
			_append_unique_relic(result, seen, relic)

	if include_auto_collected_relics:
		for relic: Relic in _collect_auto_relics():
			if relic != null and relic.level <= shop_level:
				_append_unique_relic(result, seen, relic)

	return result


func get_relics_by_level(relic_level: int) -> Array[Relic]:
	var result: Array[Relic] = []
	var seen: Dictionary = {}

	for entry: RelicPoolEntry in entries:
		if entry != null and entry.can_roll_at_relic_level(relic_level):
			_append_unique_relic(result, seen, entry.relic)

	for relic: Relic in relics:
		if relic != null and relic.level == relic_level:
			_append_unique_relic(result, seen, relic)

	if include_auto_collected_relics:
		for relic: Relic in _collect_auto_relics():
			if relic != null and relic.level == relic_level:
				_append_unique_relic(result, seen, relic)

	return result


func get_weight_for_relic(relic: Relic, fallback_weight: float = 1.0) -> float:
	if relic == null:
		return fallback_weight

	for entry: RelicPoolEntry in entries:
		if entry != null and _is_same_relic(entry.relic, relic):
			return max(entry.weight, 0.0)

	return max(default_weight, fallback_weight)


func _collect_auto_relics() -> Array[Relic]:
	var result: Array[Relic] = []
	var seen: Dictionary = {}

	for folder_path: String in auto_collect_folders:
		_collect_relics_from_folder(folder_path, result, seen)

	return result


func _collect_relics_from_folder(folder_path: String, result: Array[Relic], seen: Dictionary) -> void:
	if folder_path.is_empty() or not DirAccess.dir_exists_absolute(folder_path):
		return
	if _is_auto_collect_folder_excluded(folder_path):
		return

	var files: PackedStringArray = DirAccess.get_files_at(folder_path)
	files.sort()
	for file_name: String in files:
		var extension: String = file_name.get_extension().to_lower()
		if extension != "tres" and extension != "res":
			continue

		var resource_path: String = folder_path.path_join(file_name)
		var resource: Resource = ResourceLoader.load(resource_path)
		var relic: Relic = resource as Relic
		if relic != null:
			_append_unique_relic(result, seen, relic)

	if not auto_collect_recursive:
		return

	var directories: PackedStringArray = DirAccess.get_directories_at(folder_path)
	directories.sort()
	for directory_name: String in directories:
		if directory_name.begins_with("."):
			continue

		var child_folder_path: String = folder_path.path_join(directory_name)
		_collect_relics_from_folder(child_folder_path, result, seen)


func _append_unique_relic(result: Array[Relic], seen: Dictionary, relic: Relic) -> void:
	if not _is_rollable_relic(relic):
		return

	var key: String = _get_relic_key(relic)
	if key.is_empty() or seen.has(key):
		return

	seen[key] = true
	result.append(relic)


func _is_rollable_relic(relic: Relic) -> bool:
	if relic == null:
		return false
	if relic.level < min_relic_level:
		return false
	if require_basic_info:
		if relic.id.strip_edges().is_empty():
			return false
		if relic.relic_name.strip_edges().is_empty():
			return false
	if require_icon and relic.icon == null:
		return false
	return true


func _is_auto_collect_folder_excluded(folder_path: String) -> bool:
	var normalized_folder := _normalize_resource_path(folder_path)
	for excluded_folder: String in auto_collect_excluded_folders:
		var normalized_excluded := _normalize_resource_path(excluded_folder)
		if normalized_excluded.is_empty():
			continue
		if normalized_folder == normalized_excluded:
			return true
		if normalized_folder.begins_with("%s/" % normalized_excluded):
			return true
	return false


func _normalize_resource_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/")


func _is_same_relic(a: Relic, b: Relic) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	return _get_relic_key(a) == _get_relic_key(b)


func _get_relic_key(relic: Relic) -> String:
	if relic == null:
		return ""
	if not relic.id.is_empty():
		return "id:%s" % relic.id
	if not relic.resource_path.is_empty():
		return "path:%s" % relic.resource_path
	return "instance:%s" % str(relic.get_instance_id())
