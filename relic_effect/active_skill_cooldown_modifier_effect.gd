## 遗物效果：调整指定主动技能的冷却。
## 可以按技能 id 或技能栏位筛选，适合“基础攻击冷却 -2%”这类装备效果。
class_name ActiveSkillCooldownModifierEffect
extends RelicEffect

@export var target_ability_ids: Array[StringName] = []
@export var target_slot_indices: Array[int] = []
@export var cooldown_multiplier: float = 1.0
@export var flat_reduction: float = 0.0


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var ability_controller := owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	ability_controller.set_cooldown_modifier(effect_key, {
		"target_ability_ids": target_ability_ids.duplicate(),
		"target_slot_indices": target_slot_indices.duplicate(),
		"cooldown_multiplier": cooldown_multiplier,
		"flat_reduction": flat_reduction,
	})


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var ability_controller := owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	ability_controller.clear_cooldown_modifier(effect_key)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
