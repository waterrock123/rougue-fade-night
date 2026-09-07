class_name AlchemyDropEntry
extends Resource

## 炼金掉落池中的单个条目。
## 它只描述“什么拾取物能被抽到，以及在什么条件下抽到”，真正生成和抛出动画仍由 AlchemyStation 负责。
@export var pickup_scene: PackedScene
@export var weight: float = 1.0
@export var enabled: bool = true

@export_group("等级条件")
## 当前商店等级低于该值时不会进入候选池。
@export var min_shop_level: int = 1
## 小于等于 0 表示没有上限。
@export var max_shop_level: int = 0

@export_group("地图标签条件")
## 只有玩家在地图标签配置中启用了这些 tag 时，此条目才会进入候选池。
@export var required_enabled_tags: Array[RelicTag] = []
## 命中这些 tag 时，会提高此条目的权重。重复启用同类 tag 会重复计数。
@export var weight_bonus_tags: Array[RelicTag] = []
@export var weight_bonus_per_matching_tag: float = 0.0


func can_roll(shop_level: int, enabled_map_tag_keys: Array[String]) -> bool:
	if not enabled or pickup_scene == null or weight <= 0.0:
		return false
	if shop_level < min_shop_level:
		return false
	if max_shop_level > 0 and shop_level > max_shop_level:
		return false
	return _has_required_tags(enabled_map_tag_keys)


func get_roll_weight(enabled_map_tag_keys: Array[String]) -> float:
	var result: float = max(weight, 0.0)
	if weight_bonus_per_matching_tag == 0.0 or weight_bonus_tags.is_empty():
		return result

	var matched_count: int = 0
	for bonus_tag: RelicTag in weight_bonus_tags:
		var tag_key: String = _get_tag_key(bonus_tag)
		if tag_key.is_empty():
			continue
		matched_count += _count_enabled_tag_key(enabled_map_tag_keys, tag_key)

	return max(result + float(matched_count) * weight_bonus_per_matching_tag, 0.0)


func _has_required_tags(enabled_map_tag_keys: Array[String]) -> bool:
	for required_tag: RelicTag in required_enabled_tags:
		var tag_key: String = _get_tag_key(required_tag)
		if tag_key.is_empty():
			continue
		if not enabled_map_tag_keys.has(tag_key):
			return false
	return true


func _count_enabled_tag_key(enabled_map_tag_keys: Array[String], tag_key: String) -> int:
	var result: int = 0
	for enabled_key: String in enabled_map_tag_keys:
		if enabled_key == tag_key:
			result += 1
	return result


func _get_tag_key(tag: RelicTag) -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name
