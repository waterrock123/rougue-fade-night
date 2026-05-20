## 状态效果：给符合条件的“出伤”追加额外伤害。适合暴怒、附魔、破甲后的增伤等效果。
class_name StatusOutgoingDamageBonusEffect
extends StatusEffect

@export var target_ability_ids: Array[StringName] = []
@export var target_slot_indices: Array[int] = []
@export var required_tags: Array[String] = []
@export var flat_bonus: float = 0.0
@export var percent_bonus: float = 0.0
@export_multiline var flat_bonus_formula: String = ""


# 状态生效时，把出伤加成注册到 StatsController。
func on_apply(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	stats_controller.set_outgoing_damage_bonus_modifier(_get_effect_key(instance), {
		"target_ability_ids": target_ability_ids.duplicate(),
		"target_slot_indices": target_slot_indices.duplicate(),
		"required_tags": required_tags.duplicate(),
		"flat_bonus": flat_bonus * instance.stacks,
		"percent_bonus": percent_bonus * instance.stacks,
		"flat_bonus_formula": flat_bonus_formula,
	})


# 状态结束时，清理对应的出伤加成。
func on_remove(instance: StatusInstance) -> void:
	var stats_controller := _get_stats_controller(instance)
	if stats_controller == null:
		return

	stats_controller.clear_outgoing_damage_bonus_modifier(_get_effect_key(instance))


func _get_stats_controller(instance: StatusInstance) -> StatsController:
	if instance == null or instance.controller == null:
		return null
	return instance.controller.get_stats_controller()


func _get_effect_key(instance: StatusInstance) -> String:
	return "%s_outgoing_damage" % instance.get_effect_key()
