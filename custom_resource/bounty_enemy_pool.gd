class_name BountyEnemyPool
extends Resource

## 悬赏精英怪池。
## 这里不直接生成敌人，只负责按权重选出一条配置，实际生成由 EnemySpawner 负责。
@export var entries: Array[BountyEnemyEntry] = []


func get_random_entry() -> BountyEnemyEntry:
	var valid_entries: Array[BountyEnemyEntry] = _get_valid_entries()
	if valid_entries.is_empty():
		return null

	var total_weight: float = 0.0
	for entry in valid_entries:
		total_weight += max(entry.weight, 0.0)

	if total_weight <= 0.0:
		return valid_entries[randi_range(0, valid_entries.size() - 1)]

	var roll: float = randf() * total_weight
	var accumulated_weight: float = 0.0
	for entry in valid_entries:
		accumulated_weight += max(entry.weight, 0.0)
		if roll <= accumulated_weight:
			return entry

	return valid_entries[valid_entries.size() - 1]


func _get_valid_entries() -> Array[BountyEnemyEntry]:
	var result: Array[BountyEnemyEntry] = []
	for entry in entries:
		if entry != null and entry.is_valid_entry():
			result.append(entry)
	return result
