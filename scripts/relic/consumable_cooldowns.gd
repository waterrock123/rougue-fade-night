## 当前战斗内的消耗品冷却，按单件资源实例隔离；随场景暂停，不污染共享装备资源。
class_name ConsumableCooldowns
extends RefCounted

var records: Dictionary = {}


func tick(delta: float) -> void:
	for key: int in records.keys():
		var record: Dictionary = records[key]
		record["remaining"] = maxf(float(record["remaining"]) - delta, 0.0)
		if record["remaining"] <= 0.0 or record["relic"].get_ref() == null:
			records.erase(key)


func get_remaining(relic: Relic) -> float:
	if relic == null:
		return 0.0
	var record: Dictionary = records.get(relic.get_instance_id(), {})
	return float(record.get("remaining", 0.0))


func start(relic: Relic) -> void:
	var duration: float = relic.get_consumable_cooldown()
	if duration > 0.0:
		records[relic.get_instance_id()] = {"relic": weakref(relic), "remaining": duration}
