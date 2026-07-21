@tool
class_name AbilityCastPowerKnockbackEffect
extends RelicEffect

## 释放技能时，如果拥有指定状态，就击退周围目标。
## 当前用于“电风扇”：有电力时释放主动技能，小幅击退周围敌人。

@export var required_status_id: StringName = &"power"
@export var target_groups: Array[StringName] = [&"enemy"]
@export var radius: float = 140.0
@export var knockback_distance: float = 70.0
@export var knockback_duration: float = 0.12
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var transition_type: Tween.TransitionType = Tween.TRANS_QUAD
@export var target_slot_indices: Array[int] = []
@export var excluded_slot_indices: Array[int] = []

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		return

	var ability_controller: AbilityController = owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var key: String = str(effect_key)
	if active_entries.has(key):
		return

	var callback: Callable = Callable(self, "_on_ability_triggered").bind(owner, key)
	ability_controller.ability_triggered.connect(callback)
	active_entries[key] = {
		"controller": ability_controller,
		"callback": callback,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_entries.has(key):
		return

	var entry: Dictionary = active_entries[key] as Dictionary
	var ability_controller: AbilityController = entry.get("controller") as AbilityController
	var callback: Callable = entry.get("callback") as Callable
	if ability_controller != null and is_instance_valid(ability_controller) and callback.is_valid():
		if ability_controller.ability_triggered.is_connected(callback):
			ability_controller.ability_triggered.disconnect(callback)

	active_entries.erase(key)


func _on_ability_triggered(ability: Ability, caster: Entity, owner: Entity, _effect_key: String) -> void:
	if caster == null or owner == null or caster != owner:
		return
	if ability == null or not _ability_matches(ability):
		return
	if not _has_required_status(owner):
		return

	for target: Entity in _find_targets(owner):
		_knockback_target(owner, target)


func _ability_matches(ability: Ability) -> bool:
	if not target_slot_indices.is_empty() and not target_slot_indices.has(ability.runtime_slot_index):
		return false
	if excluded_slot_indices.has(ability.runtime_slot_index):
		return false
	return true


func _has_required_status(owner: Entity) -> bool:
	if required_status_id == &"":
		return true
	if owner == null or owner.status_controller == null:
		return false

	var status_instance: StatusInstance = owner.status_controller.get_status(required_status_id)
	return status_instance != null and status_instance.stacks > 0


func _find_targets(owner: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	if owner == null or not owner.is_inside_tree():
		return result

	var radius_squared: float = radius * radius
	for group_name: StringName in target_groups:
		for node: Node in owner.get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var target: Entity = node as Entity
			if target == owner or target.is_dead:
				continue
			if owner.global_position.distance_squared_to(target.global_position) > radius_squared:
				continue

			result.append(target)

	return result


func _knockback_target(owner: Entity, target: Entity) -> void:
	if owner == null or target == null or not is_instance_valid(target):
		return

	var direction: Vector2 = owner.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		direction = owner.get_facing_direction()

	# 这里沿用技能击退组件的简化做法：直接补间目标位置，后续有墙体碰撞需求时再升级。
	var target_position: Vector2 = target.global_position + direction.normalized() * knockback_distance
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "global_position", target_position, knockback_duration)
	tween.set_ease(ease_type)
	tween.set_trans(transition_type)
	target.register_action_tween(tween)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
