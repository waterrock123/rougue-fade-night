## 闪避成功后，按比例削减正在冷却的技能的剩余时间。
## 可选随机一个或全部技能；不改变基础冷却，冷却已结束的技能不参与随机。
class_name DodgeReduceCooldownEffect
extends RelicEffect

@export_range(0.0, 1.0, 0.01) var reduction_ratio: float = 0.5
@export var random_one: bool = false
## 留空表示包含全部主动技能和基础攻击，也包含装备授予的额外技能。
@export var target_slot_indices: Array[int] = []

var connections: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not context.owner is Entity:
		return
	var owner: Entity = context.owner as Entity
	var key: String = "%d:%s" % [owner.get_instance_id(), str(effect_key)]
	if connections.has(key):
		return
	var callback: Callable = _on_evaded.bind(owner, key)
	owner.damage_evaded.connect(callback)
	connections[key] = {"owner": owner, "callback": callback}


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var key: String = "%d:%s" % [context.owner.get_instance_id(), str(effect_key)]
	var record: Dictionary = connections.get(key, {})
	var owner_value: Variant = record.get("owner")
	var callback: Callable = record.get("callback", Callable())
	# 先检查实例有效性，避免离开战斗后把已释放对象强转成 Entity。
	if is_instance_valid(owner_value) and owner_value is Entity:
		var owner: Entity = owner_value as Entity
		if owner.damage_evaded.is_connected(callback):
			owner.damage_evaded.disconnect(callback)
	connections.erase(key)


func _on_evaded(_damage: DamageData, owner: Entity, _key: String) -> void:
	if not is_instance_valid(owner) or owner.is_dead:
		return
	var controller: AbilityController = owner.get_node_or_null("AbilityController") as AbilityController
	if controller == null:
		return
	var candidates: Array[Ability] = []
	for index: int in range(controller.abilities.size()):
		var ability: Ability = controller.abilities[index]
		if not is_instance_valid(ability):
			continue
		if not target_slot_indices.is_empty() and not target_slot_indices.has(index):
			continue
		if float(controller.cooldowns.get(ability, 0.0)) > 0.0:
			candidates.append(ability)
	if random_one and not candidates.is_empty():
		var chosen: Ability = candidates[randi_range(0, candidates.size() - 1)]
		candidates.assign([chosen])
	for ability: Ability in candidates:
		controller.reduce_remaining_cooldown(ability, reduction_ratio)
