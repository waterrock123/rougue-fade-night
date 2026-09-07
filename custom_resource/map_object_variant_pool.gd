class_name MapObjectVariantPool
extends Resource

## 通用地图物体变体池。
## 生成器先决定生成“哪一类物体”，再从这里按权重决定具体物体。
@export var entries: Array[MapObjectVariantEntry] = []


func pick_weighted_object_id(weight_bonuses: Dictionary = {}) -> StringName:
	var valid_entries: Array[MapObjectVariantEntry] = []
	var total_weight: float = 0.0

	for entry: MapObjectVariantEntry in entries:
		if entry == null or not entry.is_valid_entry():
			continue

		var bonus: float = float(weight_bonuses.get(String(entry.object_id), 0.0))
		var effective_weight: float = max(entry.weight + bonus, 0.0)
		if effective_weight <= 0.0:
			continue

		valid_entries.append(entry)
		total_weight += effective_weight

	if valid_entries.is_empty() or total_weight <= 0.0:
		return &""

	var roll: float = _roll_float(0.0, total_weight)
	var accumulated_weight: float = 0.0
	for entry: MapObjectVariantEntry in valid_entries:
		var bonus: float = float(weight_bonuses.get(String(entry.object_id), 0.0))
		accumulated_weight += max(entry.weight + bonus, 0.0)
		if roll <= accumulated_weight:
			return entry.object_id

	return valid_entries[valid_entries.size() - 1].object_id


func _roll_float(from: float, to: float) -> float:
	if RunRng != null and RunRng.seed_value != 0:
		return RunRng.randf_range(from, to)
	return randf_range(from, to)

