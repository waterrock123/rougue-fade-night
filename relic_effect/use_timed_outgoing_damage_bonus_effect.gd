## 消耗品使用后，临时为符合条件的伤害追加额外伤害。
## 用于松脂这类“基础攻击附带火焰伤害，持续一段时间”的效果。
class_name UseTimedOutgoingDamageBonusEffect
extends RelicEffect

@export var target_slot_indices: Array[int] = []
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var flat_bonus: float = 0.0
@export var percent_bonus: float = 0.0
@export var duration: float = 30.0
@export var levelup_duration: float = -1.0


func on_use(relic_context: RelicContext, effect_key) -> void:
	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	stats_controller.set_outgoing_damage_bonus_modifier(effect_key, {
		"target_slot_indices": target_slot_indices.duplicate(),
		"required_tags": required_tags.duplicate(),
		"required_damage_types": required_damage_types.duplicate(),
		"flat_bonus": flat_bonus,
		"percent_bonus": percent_bonus,
	})

	var final_duration := _get_duration(relic_context)
	if final_duration > 0.0:
		_clear_after_delay(stats_controller, effect_key, final_duration)


func _clear_after_delay(stats_controller: StatsController, effect_key: String, delay: float) -> void:
	await stats_controller.get_tree().create_timer(delay).timeout
	if stats_controller != null and is_instance_valid(stats_controller):
		stats_controller.clear_outgoing_damage_bonus_modifier(effect_key)


func _get_duration(relic_context: RelicContext) -> float:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_duration >= 0.0:
			return levelup_duration
	return duration


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	return null
