## 状态持续期间，符合条件的命中追加指定类型的伤害。适用于冰霜附魔等临时效果。
class_name StatusOutgoingExtraDamageEffect
extends StatusEffect

@export var target_slot_indices: Array[int] = [0]
@export var extra_damage: float = 5.0
## 按命中时的当前属性计算附加伤害；空名称表示仅使用固定伤害。
@export var scaling_stat: StringName = &""
@export var stat_multiplier: float = 0.0
## 以本次实际造成的伤害为基数追加独立伤害包，不会改变原伤害类型。
@export var dealt_damage_fraction: float = 0.0
@export var excluded_slot_indices: Array[int] = []
@export var require_ability_source: bool = false
@export var damage_types: Array[int] = [DamageData.DamageType.ICE]
@export var recursion_guard_tag: String = "status_extra_damage"

var connections: Dictionary = {}


func on_apply(instance: StatusInstance) -> void:
	if instance == null or not is_instance_valid(instance.target) or not (instance.target is Entity):
		return
	var key: int = instance.get_instance_id()
	if connections.has(key):
		return
	var entity: Entity = instance.target as Entity
	var callback: Callable = _on_damage.bind(instance)
	var exit_callback: Callable = _clear_connection.bind(key)
	entity.damage_dealt.connect(callback)
	entity.tree_exiting.connect(exit_callback, CONNECT_ONE_SHOT)
	connections[key] = {"target": weakref(entity), "callback": callback, "exit_callback": exit_callback}


func on_remove(instance: StatusInstance) -> void:
	_clear_connection(instance.get_instance_id())


func _clear_connection(key: int) -> void:
	var record: Dictionary = connections.get(key, {})
	connections.erase(key)
	if record.is_empty():
		return
	var value: Variant = record["target"].get_ref()
	if is_instance_valid(value):
		var entity: Entity = value as Entity
		if entity.damage_dealt.is_connected(record["callback"]):
			entity.damage_dealt.disconnect(record["callback"])
		if entity.tree_exiting.is_connected(record["exit_callback"]):
			entity.tree_exiting.disconnect(record["exit_callback"])


func _on_damage(data: DamageData, instance: StatusInstance) -> void:
	if data == null or not is_instance_valid(instance.target) or not is_instance_valid(data.target):
		return
	var entity: Entity = instance.target as Entity
	if entity.is_dead or data.target.is_dead or data.target.current_health <= 0.0 or data.final_damage <= 0.0:
		return
	if data.tags.has(recursion_guard_tag) or data.tags.has("extra_hit"):
		return
	if excluded_slot_indices.has(data.source_ability_slot_index):
		return
	if require_ability_source and data.source_ability_slot_index < 0:
		return
	if not target_slot_indices.is_empty() and not target_slot_indices.has(data.source_ability_slot_index):
		return
	# 独立伤害包保留 ICE 类型与来源，避免把整次基础攻击错误地改成冰伤，也防止递归触发自身。
	var tags: Array[String] = ["status", "extra_hit", recursion_guard_tag]
	var amount: float = extra_damage + data.final_damage * dealt_damage_fraction
	if scaling_stat != &"" and entity.stats_controller != null:
		amount += entity.stats_controller.get_stat(scaling_stat) * stat_multiplier
	if amount <= 0.0:
		return
	var extra: DamageData = DamageData.create(
		maxf(amount, 0.0) * instance.stacks, damage_types, tags, entity, data.target,
		false, null, data.source_ability_id, data.source_ability_slot_index, 0.0
	)
	data.target.apply_damage(extra)
