## 遗物效果：战斗结算时随机重置自身标签。
## 适合“万变饮料瓶”这类会在关卡结束后改变套装归属的装备。
class_name BattleEndRandomizeSelfTagsEffect
extends RelicEffect

## 手动指定的随机标签池。为空时会从 tag_folder_paths 自动加载。
@export var tag_pool: Array[RelicTag] = []
## 自动加载标签资源的目录。默认读取 res://relic_tags 下的 .tres / .res。
@export var tag_folder_paths: PackedStringArray = ["res://relic_tags"]
## 未升级时随机保留多少个标签。小于等于 0 时使用当前标签数量。
@export var base_random_tag_count: int = 1
## 升级态额外获得的随机标签数量。
@export var levelup_extra_random_tag_count: int = 1
## 是否避免抽到重复 tag。
@export var unique_tags: bool = true
## 标签变化后是否通知装备/UI刷新。
@export var emit_equipment_update: bool = true

var active_contexts: Dictionary = {}


## 装备生效时等待战斗奖励结算信号。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return

	active_contexts[str(effect_key)] = relic_context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


## 装备失效时移除记录；没有实例后断开信号。
func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	var contexts: Array = active_contexts.values()
	var changed_any: bool = false

	for context_value in contexts:
		var relic_context: RelicContext = context_value as RelicContext
		if _randomize_relic_tags(relic_context):
			changed_any = true

	if changed_any and emit_equipment_update:
		EventBus.equipment_update.emit()


func _randomize_relic_tags(relic_context: RelicContext) -> bool:
	if relic_context == null or relic_context.own_relic == null:
		return false

	var relic: Relic = relic_context.own_relic
	var random_tag_count: int = _get_random_tag_count(relic)
	if random_tag_count <= 0:
		return false

	var new_tags: Array[RelicTag] = _pick_random_tags(random_tag_count)
	if new_tags.is_empty():
		return false

	relic.tags = new_tags
	return true


func _get_random_tag_count(relic: Relic) -> int:
	var count: int = base_random_tag_count
	if count <= 0 and relic != null:
		count = relic.tags.size()

	if relic != null and relic.leveltip == Relic.LevelTip.LEVELUP:
		count += max(levelup_extra_random_tag_count, 0)

	return max(count, 0)


func _pick_random_tags(count: int) -> Array[RelicTag]:
	var candidates: Array[RelicTag] = _get_available_tag_pool()
	if candidates.is_empty():
		return []

	RunRng.shuffle_array(candidates)

	var result: Array[RelicTag] = []
	var used_keys: Array[String] = []
	for tag in candidates:
		if tag == null:
			continue

		var tag_key: String = _get_tag_key(tag)
		if unique_tags and used_keys.has(tag_key):
			continue

		result.append(tag)
		used_keys.append(tag_key)
		if result.size() >= count:
			break

	return result


func _get_available_tag_pool() -> Array[RelicTag]:
	var result: Array[RelicTag] = []
	var used_keys: Array[String] = []

	for tag in tag_pool:
		_append_unique_tag(result, used_keys, tag)

	if result.is_empty():
		for folder_path in tag_folder_paths:
			_collect_tags_from_folder(String(folder_path), result, used_keys)

	return result


func _collect_tags_from_folder(folder_path: String, result: Array[RelicTag], used_keys: Array[String]) -> void:
	if folder_path.is_empty():
		return

	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and _is_tag_resource_file(file_name):
			var resource_path: String = "%s/%s" % [folder_path.trim_suffix("/"), file_name]
			var resource: Resource = ResourceLoader.load(resource_path)
			_append_unique_tag(result, used_keys, resource as RelicTag)
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_tag_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res")


func _append_unique_tag(result: Array[RelicTag], used_keys: Array[String], tag: RelicTag) -> void:
	if tag == null:
		return

	var tag_key: String = _get_tag_key(tag)
	if unique_tags and used_keys.has(tag_key):
		return

	result.append(tag)
	used_keys.append(tag_key)


func _get_tag_key(tag: RelicTag) -> String:
	if tag == null:
		return ""
	if not tag.tag_name.is_empty():
		return tag.tag_name
	return tag.resource_path
