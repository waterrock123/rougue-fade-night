## 穿戴时为自己造成的伤害注册防御穿透，不通过追加伤害“补回减伤”，避免二次命中与递归。
## 固定减伤和百分比减伤独立配置；默认只忽略护甲对应的固定减伤，不影响闪避、护盾、易伤。
class_name OutgoingDefenseBypassEffect
extends RelicEffect

@export var ignore_static_damage_reduction: bool = true
@export var ignore_damage_reduction_rate: bool = false
@export var exclude_self_damage: bool = true
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []


func on_activate(context: RelicContext, effect_key: Variant) -> void:
	var controller: StatsController = _get_controller(context)
	if controller != null:
		controller.set_outgoing_defense_bypass_modifier(effect_key, {
			"ignore_static_damage_reduction": ignore_static_damage_reduction,
			"ignore_damage_reduction_rate": ignore_damage_reduction_rate,
			"exclude_self_damage": exclude_self_damage,
			"required_tags": required_tags.duplicate(),
			"required_damage_types": required_damage_types.duplicate(),
		})


func on_deactivate(context: RelicContext, effect_key: Variant) -> void:
	var controller: StatsController = _get_controller(context)
	if controller != null:
		controller.clear_outgoing_defense_bypass_modifier(effect_key)


func _get_controller(context: RelicContext) -> StatsController:
	if context == null or not is_instance_valid(context.owner):
		return null
	if is_instance_valid(context.relic_controller):
		return context.relic_controller.get_stats_controller()
	return context.owner.get_node_or_null("StatsController") as StatsController
