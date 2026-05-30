class_name PassiveBattleEndConsumeEquipmentForStatsEffect
extends PassiveSkillEffect

enum ConsumeMode {
	LEFTMOST,
	ALL,
}

# 战斗胜利后消耗装备，并按被消耗装备的阶数永久提升随机一级属性。
# LEFTMOST 只吃最左边一件；ALL 会吃掉装备栏里全部装备。
@export var consume_mode: ConsumeMode = ConsumeMode.LEFTMOST
@export var candidate_stats: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null:
		return
	if context.caster == null or not context.caster.is_in_group("player"):
		return

	active_contexts[_get_context_key(context)] = context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	for value in active_contexts.values():
		var context := value as SkillContext
		if context != null:
			_consume_equipment(context)


func _consume_equipment(context: SkillContext) -> void:
	var equipment := _get_equipment(context)
	if equipment == null:
		return

	match consume_mode:
		ConsumeMode.LEFTMOST:
			_consume_leftmost(context, equipment)
		ConsumeMode.ALL:
			_consume_all(context, equipment)


func _consume_leftmost(context: SkillContext, equipment: Equipment) -> void:
	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue

		var consumed_relic := slot.item
		RelicConsumption.consume_slot(slot, context.caster, _get_relic_controller(context), _build_consume_key(context, consumed_relic), false)
		_grant_random_permanent_stat(context, consumed_relic)
		_emit_updates()
		return


func _consume_all(context: SkillContext, equipment: Equipment) -> void:
	var consumed_any := false
	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue

		var consumed_relic := slot.item
		RelicConsumption.consume_slot(slot, context.caster, _get_relic_controller(context), _build_consume_key(context, consumed_relic), false)
		_grant_random_permanent_stat(context, consumed_relic)
		consumed_any = true

	if consumed_any:
		_emit_updates()


func _grant_random_permanent_stat(context: SkillContext, relic: Relic) -> void:
	if context.player_build == null or context.player_build.player_stats == null or relic == null:
		return
	if candidate_stats.is_empty():
		return

	var stat_name = candidate_stats.pick_random()
	var amount = max(int(relic.level), 1)
	var stats_data := context.player_build.player_stats

	match stat_name:
		&"strength":
			stats_data.strength += amount
		&"dexterity":
			stats_data.dexterity += amount
		&"intelligence":
			stats_data.intelligence += amount
		&"constitution":
			stats_data.constitution += amount
		&"speed":
			stats_data.speed += amount
		&"charm":
			stats_data.charm += amount
		&"luck":
			stats_data.luck += amount


func _emit_updates() -> void:
	AudioController.play_ui_sound(&"sell_item")
	EventBus.equipment_update.emit()
	EventBus.attribute_update.emit()


func _get_equipment(context: SkillContext) -> Equipment:
	if context.player_build == null:
		return null
	return context.player_build.player_equipment


func _get_relic_controller(context: SkillContext) -> RelicController:
	if context == null or context.caster == null:
		return null
	return context.caster.get_node_or_null("RelicController") as RelicController


func _build_consume_key(context: SkillContext, relic: Relic) -> String:
	var relic_id = relic.id if relic != null else "unknown"
	return "%s_consumed_%s_%s" % [str(context.effect_key), relic_id, Time.get_ticks_msec()]


func _get_context_key(context: SkillContext) -> String:
	var owner_id := 0
	if context.skill_controller != null:
		owner_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(owner_id), str(context.effect_key)]
