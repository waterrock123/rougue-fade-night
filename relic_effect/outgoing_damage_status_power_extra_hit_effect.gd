@tool
class_name OutgoingDamageStatusPowerExtraHitEffect
extends RelicEffect

## 在拥有者造成指定伤害后，追加一次额外伤害。
## 额外伤害会读取某个 status 的当前层数，并可在触发时消耗层数。

@export var target_ability_ids: Array[StringName] = []
@export var target_slot_indices: Array[int] = []
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var require_positive_damage: bool = true

@export var base_extra_damage: float = 1.0
@export var damage_per_status_stack: float = 1.0
@export var extra_damage_types: Array[int] = [DamageData.DamageType.LIGHTNING]
@export var extra_tags: Array[String] = ["relic", "extra_hit", "lightning"]
@export var can_crit: bool = false
## 由状态层数产生的追加伤害默认不重复削韧。
@export var poise_damage: float = 0.0

@export var status_id: StringName = &"power"
@export var status_stacks_to_consume: int = 1
@export var recursion_guard_tag: String = "status_power_extra_hit_guard"

var _active_owners: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	var owner_entity: Entity = _get_owner_entity(context)
	if owner_entity == null:
		return

	var key: String = _make_key(context, effect_key)
	if _active_owners.has(key):
		return

	_active_owners[key] = owner_entity
	if not owner_entity.damage_dealt.is_connected(_on_owner_damage_dealt):
		owner_entity.damage_dealt.connect(_on_owner_damage_dealt)


func on_deactivate(context: RelicContext, effect_key) -> void:
	var key: String = _make_key(context, effect_key)
	_active_owners.erase(key)

	var owner_entity: Entity = _get_owner_entity(context)
	if owner_entity != null and is_instance_valid(owner_entity) and not _has_active_owner(owner_entity) and owner_entity.damage_dealt.is_connected(_on_owner_damage_dealt):
		owner_entity.damage_dealt.disconnect(_on_owner_damage_dealt)


func _on_owner_damage_dealt(damage_data: DamageData) -> void:
	if damage_data == null:
		return
	if damage_data.source == null or damage_data.target == null:
		return
	if not is_instance_valid(damage_data.source) or not is_instance_valid(damage_data.target):
		return
	if not _has_active_owner(damage_data.source):
		return
	if not _matches_damage(damage_data):
		return

	var status_stacks: int = _get_status_stacks(damage_data.source)
	var extra_damage: float = base_extra_damage + float(status_stacks) * damage_per_status_stack
	if extra_damage <= 0.0:
		return

	_consume_status_stacks(damage_data.source, status_stacks)
	_apply_extra_damage(damage_data, extra_damage)


func _matches_damage(damage_data: DamageData) -> bool:
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return false
	if damage_data.tags.has(recursion_guard_tag):
		return false
	if not target_ability_ids.is_empty() and not target_ability_ids.has(damage_data.source_ability_id):
		return false
	if not target_slot_indices.is_empty() and not target_slot_indices.has(damage_data.source_ability_slot_index):
		return false
	if not _has_all_required_tags(damage_data):
		return false
	if not _has_all_required_damage_types(damage_data):
		return false
	return true


func _has_all_required_tags(damage_data: DamageData) -> bool:
	for required_tag: String in required_tags:
		if not damage_data.tags.has(required_tag):
			return false
	return true


func _has_all_required_damage_types(damage_data: DamageData) -> bool:
	for required_type: int in required_damage_types:
		if not damage_data.damage_types.has(required_type):
			return false
	return true


func _get_status_stacks(owner_entity: Entity) -> int:
	var status_controller: StatusController = owner_entity.get_status_controller()
	if status_controller == null:
		return 0

	var status_instance: StatusInstance = status_controller.get_status(status_id)
	if status_instance == null:
		return 0
	return max(status_instance.stacks, 0)


func _consume_status_stacks(owner_entity: Entity, current_stacks: int) -> void:
	if current_stacks <= 0 or status_stacks_to_consume <= 0:
		return

	var status_controller: StatusController = owner_entity.get_status_controller()
	if status_controller == null:
		return

	# 本次伤害按触发前的层数结算，随后消耗指定层数。
	status_controller.consume_status_stacks(status_id, min(status_stacks_to_consume, current_stacks))


func _apply_extra_damage(source_damage: DamageData, extra_damage: float) -> void:
	var tags: Array[String] = extra_tags.duplicate()
	if not tags.has(recursion_guard_tag):
		tags.append(recursion_guard_tag)

	var extra_damage_data: DamageData = DamageData.create(
		extra_damage,
		extra_damage_types,
		tags,
		source_damage.source,
		source_damage.target,
		can_crit,
		null,
		source_damage.source_ability_id,
		source_damage.source_ability_slot_index,
		poise_damage
	)
	source_damage.target.apply_damage(extra_damage_data)


func _has_active_owner(owner_entity: Entity) -> bool:
	for stored_owner in _active_owners.values():
		if stored_owner == null or not is_instance_valid(stored_owner):
			continue
		if stored_owner == owner_entity:
			return true
	return false


func _get_owner_entity(context: RelicContext) -> Entity:
	if context == null:
		return null
	if context.owner is Entity:
		return context.owner as Entity
	return null


func _make_key(context: RelicContext, effect_key) -> String:
	var key_text: String = str(effect_key)
	if not key_text.is_empty():
		return key_text
	if context == null:
		return str(get_instance_id())
	return "%s:%s" % [str(context.relic_key), str(get_instance_id())]
