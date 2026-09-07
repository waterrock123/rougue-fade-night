class_name AlchemyDropPool
extends Resource

## 炼金掉落池。
## AlchemyStation 只向它请求一个 PackedScene，池子负责根据等级、地图标签和权重挑选掉落物。
@export var entries: Array[AlchemyDropEntry] = []


func pick_random_pickup_scene(shop_level: int, enabled_map_tag_keys: Array[String]) -> PackedScene:
	var candidates: Array[AlchemyDropEntry] = _get_candidates(shop_level, enabled_map_tag_keys)
	if candidates.is_empty():
		return null

	var total_weight: float = 0.0
	for entry: AlchemyDropEntry in candidates:
		total_weight += entry.get_roll_weight(enabled_map_tag_keys)

	if total_weight <= 0.0:
		return candidates[randi_range(0, candidates.size() - 1)].pickup_scene

	var roll: float = randf() * total_weight
	var accumulated_weight: float = 0.0
	for entry: AlchemyDropEntry in candidates:
		accumulated_weight += entry.get_roll_weight(enabled_map_tag_keys)
		if roll <= accumulated_weight:
			return entry.pickup_scene

	return candidates[candidates.size() - 1].pickup_scene


func _get_candidates(shop_level: int, enabled_map_tag_keys: Array[String]) -> Array[AlchemyDropEntry]:
	var result: Array[AlchemyDropEntry] = []
	for entry: AlchemyDropEntry in entries:
		if entry == null:
			continue
		if entry.can_roll(shop_level, enabled_map_tag_keys):
			result.append(entry)
	return result
