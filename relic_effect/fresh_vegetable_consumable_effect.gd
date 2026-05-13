class_name FreshVegetableConsumableEffect
extends RelicEffect

@export var self_damage: float = 0.0
@export var heal_amount: float = 0.0
@export var add_stats: Dictionary = {}


# 鲜艳蔬菜的使用效果：
# 1. 可配置自伤，用于表现“鲜艳但危险”的代价。
# 2. 可配置本场战斗内的一级属性加成。
# 3. 可配置直接治疗，升级态效果可以单独用一份资源只填治疗值。
func on_use(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or relic_context.owner == null:
		return

	var owner := relic_context.owner
	_apply_self_damage(owner)
	_apply_stat_bonus(relic_context, String(effect_key))
	_apply_heal(owner)


func _apply_self_damage(owner: Node) -> void:
	if self_damage <= 0.0:
		return
	if not owner.has_method("apply_damage"):
		return

	var target := owner as Entity
	var damage_data := DamageData.create(
		self_damage,
		[DamageData.DamageType.PHYSICAL],
		["consumable", "fresh_vegetable"],
		null,
		target,
		false
	)
	owner.apply_damage(damage_data)


func _apply_stat_bonus(relic_context: RelicContext, effect_key: String) -> void:
	if add_stats.is_empty():
		return

	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	var modifiers: Array[Modifier] = []
	for stat_name in add_stats.keys():
		var amount := float(add_stats[stat_name])
		modifiers.append(Modifier.create_flat(StringName(stat_name), amount, effect_key))

	stats_controller.set_effect_modifiers(effect_key, modifiers)


func _apply_heal(owner: Node) -> void:
	if heal_amount <= 0.0:
		return
	if not (owner is Entity):
		return

	var entity := owner as Entity
	entity.current_health = min(entity.current_health + heal_amount, entity.max_health)
	if entity.stats_controller != null:
		entity.stats_controller.current_health = entity.current_health
		entity.stats_controller.sync_runtime_resources()

	if entity.is_in_group("player"):
		EventBus.player_health_changed.emit(entity.current_health, entity.max_health)


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	return relic_context.owner.get_node_or_null("StatsController") as StatsController
