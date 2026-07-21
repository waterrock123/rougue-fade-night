class_name MapObjectSpawnProfile
extends Resource

## 一张战斗地图使用的一组地图物件随机生成规则。
## 先按每条 Rule 的数量生成；如需“再额外随机若干个物件”，可开启 weighted_bonus。

@export var enabled: bool = true
@export var rules: Array[MapObjectSpawnRule] = []

@export_group("额外权重补充")
@export var use_weighted_bonus_spawns: bool = false
@export var bonus_min_count: int = 0
@export var bonus_max_count: int = 0


func get_enabled_rules() -> Array[MapObjectSpawnRule]:
	var result: Array[MapObjectSpawnRule] = []
	if not enabled:
		return result

	for rule: MapObjectSpawnRule in rules:
		if rule == null or not rule.is_valid_rule():
			continue
		result.append(rule)

	return result


func roll_bonus_count() -> int:
	if not enabled or not use_weighted_bonus_spawns:
		return 0

	var safe_min_count: int = max(bonus_min_count, 0)
	var safe_max_count: int = max(bonus_max_count, safe_min_count)
	return randi_range(safe_min_count, safe_max_count)


func pick_weighted_rule() -> MapObjectSpawnRule:
	var candidates: Array[MapObjectSpawnRule] = []
	var total_weight: float = 0.0
	for rule: MapObjectSpawnRule in rules:
		if rule == null or not rule.can_be_weighted_pick():
			continue
		candidates.append(rule)
		total_weight += max(rule.weight, 0.0)

	if candidates.is_empty() or total_weight <= 0.0:
		return null

	var roll: float = randf() * total_weight
	var accumulated_weight: float = 0.0
	for rule: MapObjectSpawnRule in candidates:
		accumulated_weight += max(rule.weight, 0.0)
		if roll <= accumulated_weight:
			return rule

	return candidates[candidates.size() - 1]
