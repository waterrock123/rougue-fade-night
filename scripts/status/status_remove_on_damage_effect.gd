## 状态效果：目标受到伤害时移除此状态。
## 适合睡眠、隐身、蓄力、冥想等“被打断”的状态。
class_name StatusRemoveOnDamageEffect
extends StatusEffect

## 低于该最终伤害时不解除。默认 0 表示只要 Entity 发出了 damage_taken 信号就解除。
@export var min_final_damage: float = 0.0

var connected_targets: Dictionary = {}


func on_apply(instance: StatusInstance) -> void:
	var target := _get_target_entity(instance)
	if target == null or instance.controller == null:
		return

	var key := _get_connection_key(instance)
	if connected_targets.has(key):
		return

	var callback := Callable(self, "_on_damage_taken").bind(instance.controller, instance.get_status_id(), key)
	if not target.damage_taken.is_connected(callback):
		target.damage_taken.connect(callback)
	connected_targets[key] = {
		"target": target,
		"callback": callback,
	}


func on_remove(instance: StatusInstance) -> void:
	_disconnect_instance(instance)


func _on_damage_taken(
	damage_data: DamageData,
	controller: StatusController,
	status_id: StringName,
	connection_key: String
) -> void:
	if damage_data == null or damage_data.final_damage < min_final_damage:
		return
	if controller == null or not is_instance_valid(controller):
		connected_targets.erase(connection_key)
		return

	# 延迟到当前伤害结算结束后再移除状态，避免在伤害回调链中立刻改状态表。
	controller.call_deferred("remove_status", status_id)


func _disconnect_instance(instance: StatusInstance) -> void:
	var key := _get_connection_key(instance)
	var record = connected_targets.get(key)
	if not (record is Dictionary):
		return

	var target := record.get("target") as Entity
	var callback := record.get("callback") as Callable
	if target != null and is_instance_valid(target) and target.damage_taken.is_connected(callback):
		target.damage_taken.disconnect(callback)
	connected_targets.erase(key)


func _get_target_entity(instance: StatusInstance) -> Entity:
	if instance == null or not (instance.target is Entity):
		return null
	return instance.target as Entity


func _get_connection_key(instance: StatusInstance) -> String:
	if instance == null:
		return ""
	return instance.get_effect_key() + "_remove_on_damage"
