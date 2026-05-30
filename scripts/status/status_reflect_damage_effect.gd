## 状态效果：目标受到伤害后，对伤害来源造成反伤。
## 适合荆棘护甲、尖刺外壳、火焰护盾等“被打会反击”的状态复用。
class_name StatusReflectDamageEffect
extends StatusEffect

## 每层状态提供的固定反伤。状态层数越高，反伤越高。
@export var flat_damage_per_stack: float = 4.0
## 按本次实际受到伤害的比例反伤。0.25 表示每层反弹 25% 受到的最终伤害。
@export var percent_taken_damage_per_stack: float = 0.0
## 反伤最低值，避免百分比反伤在小伤害时完全没有存在感。
@export var minimum_damage: float = 0.0
## 反伤伤害类型，用于飘字颜色和后续抗性/关键词扩展。
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
## 反伤标签。默认带 reflect，用来阻止反伤再次触发反伤。
@export var tags: Array[String] = ["status", "reflect"]
## 这些标签的入站伤害不会触发反伤，防止反伤套反伤形成循环。
@export var ignored_incoming_tags: Array[String] = ["reflect", "retaliation"]
## 是否只有实际扣血大于 0 时才触发。
@export var require_positive_damage: bool = true
## 反伤是否允许暴击。默认关闭，避免防御型状态出现过强爆发。
@export var can_crit: bool = false

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
	var instance := controller.get_status(status_id) if controller != null and is_instance_valid(controller) else null
	if instance == null:
		connected_targets.erase(connection_key)
		return
	if not _can_reflect(damage_data, instance):
		return

	var defender := instance.target as Entity
	var attacker := damage_data.source
	var reflect_damage := _get_reflect_damage(damage_data, instance)
	if reflect_damage <= 0.0:
		return

	var reflect_data := DamageData.create(
		reflect_damage,
		damage_types,
		tags,
		defender,
		attacker,
		can_crit
	)
	attacker.apply_damage(reflect_data)


func _can_reflect(damage_data: DamageData, instance: StatusInstance) -> bool:
	if damage_data == null or instance == null:
		return false
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return false
	for tag in ignored_incoming_tags:
		if damage_data.tags.has(tag):
			return false
	if not (instance.target is Entity):
		return false
	if damage_data.source == null or not is_instance_valid(damage_data.source):
		return false
	if damage_data.source == instance.target:
		return false
	if damage_data.source.is_dead:
		return false
	return true


func _get_reflect_damage(damage_data: DamageData, instance: StatusInstance) -> float:
	var stack_count: int = max(instance.stacks, 1)
	var flat_damage := flat_damage_per_stack * stack_count
	var percent_damage := damage_data.final_damage * percent_taken_damage_per_stack * stack_count
	return max(flat_damage + percent_damage, minimum_damage)


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
	return "%s_reflect_damage" % instance.get_effect_key()
