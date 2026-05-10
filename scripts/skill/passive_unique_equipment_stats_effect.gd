class_name PassiveUniqueEquipmentStatsEffect
extends PassiveSkillEffect

# 按“不同装备 id 数量”提供属性加成。
# 同 id 的升级/未升级装备只算一种，适合“全副武装”这类鼓励装备多样性的被动。
@export var stats_per_unique_relic: Dictionary = {
	"strength": 1,
	"dexterity": 1,
}

var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.effect_key == null:
		return

	active_contexts[_get_context_key(context)] = context
	if not EventBus.equipment_update.is_connected(_on_equipment_update):
		EventBus.equipment_update.connect(_on_equipment_update)

	_refresh_context(context)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	if context.stats_controller != null:
		context.stats_controller.clear_effect_modifiers(context.effect_key)

	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.equipment_update.is_connected(_on_equipment_update):
		EventBus.equipment_update.disconnect(_on_equipment_update)


func _on_equipment_update() -> void:
	for value in active_contexts.values():
		var context := value as SkillContext
		if context != null:
			_refresh_context(context)


func _refresh_context(context: SkillContext) -> void:
	if context.stats_controller == null:
		return

	var unique_count := _get_unique_equipped_relic_count(context)
	var modifiers: Array[Modifier] = []
	for stat_name in stats_per_unique_relic.keys():
		var amount := float(stats_per_unique_relic[stat_name]) * unique_count
		if amount != 0.0:
			modifiers.append(Modifier.create_flat(StringName(stat_name), amount, context.effect_key))

	context.stats_controller.set_effect_modifiers(context.effect_key, modifiers)


func _get_unique_equipped_relic_count(context: SkillContext) -> int:
	if context.player_build == null or context.player_build.player_equipment == null:
		return 0

	var seen_ids: Array[String] = []
	for slot in context.player_build.player_equipment.equip_slots:
		if slot == null or slot.item == null:
			continue

		var relic_id := slot.item.id
		if relic_id.is_empty() or seen_ids.has(relic_id):
			continue

		seen_ids.append(relic_id)

	return seen_ids.size()


func _get_context_key(context: SkillContext) -> String:
	var owner_id := 0
	if context.skill_controller != null:
		owner_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(owner_id), str(context.effect_key)]
