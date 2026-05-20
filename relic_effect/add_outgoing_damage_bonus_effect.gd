## 遗物效果：为拥有者注册出伤加成。
## 可按技能 id、技能槽位、伤害标签、伤害类型筛选，适合“冰冻伤害 +2”“火焰技能 +10%”等装备效果。
class_name AddOutgoingDamageBonusEffect
extends RelicEffect

@export var target_ability_ids: Array[StringName] = []
@export var target_slot_indices: Array[int] = []
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var flat_bonus: float = 0.0
@export var percent_bonus: float = 0.0
@export_multiline var flat_bonus_formula: String = ""


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	stats_controller.set_outgoing_damage_bonus_modifier(effect_key, {
		"target_ability_ids": target_ability_ids.duplicate(),
		"target_slot_indices": target_slot_indices.duplicate(),
		"required_tags": required_tags.duplicate(),
		"required_damage_types": required_damage_types.duplicate(),
		"flat_bonus": flat_bonus,
		"percent_bonus": percent_bonus,
		"flat_bonus_formula": flat_bonus_formula,
	})


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	stats_controller.clear_outgoing_damage_bonus_modifier(effect_key)


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null
