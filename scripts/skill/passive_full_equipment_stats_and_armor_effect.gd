class_name PassiveFullEquipmentStatsAndArmorEffect
extends PassiveSkillEffect

# 装备栏全满时提供护甲和属性。
# 这里把护甲作为 Status 添加，方便和装备护甲共用同 id 多来源叠层系统。
@export var armor_status: StatusData = preload("res://status/armor.tres")
@export var armor_stacks: int = 1
@export var full_equipment_stats: Dictionary = {}

var active_contexts: Dictionary = {}
var armor_applied: Dictionary = {}
var stats_applied: Dictionary = {}


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

	_remove_bonus(context)
	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.equipment_update.is_connected(_on_equipment_update):
		EventBus.equipment_update.disconnect(_on_equipment_update)


func _on_equipment_update() -> void:
	for value in active_contexts.values():
		var context := value as SkillContext
		if context != null:
			_refresh_context(context)


func _refresh_context(context: SkillContext) -> void:
	if _is_equipment_full(context):
		_apply_bonus(context)
	else:
		_remove_bonus(context)


func _apply_bonus(context: SkillContext) -> void:
	var context_key := _get_context_key(context)

	if context.stats_controller != null and not stats_applied.has(context_key):
		context.stats_controller.set_effect_modifiers(_get_stats_effect_key(context), _build_stat_modifiers(context))
		stats_applied[context_key] = true

	if not armor_applied.has(context_key):
		var status_controller := _get_status_controller(context)
		if status_controller != null and armor_status != null and armor_stacks > 0:
			status_controller.add_status(armor_status, _get_source_node(context), _get_armor_effect_key(context), armor_stacks)
			armor_applied[context_key] = true


func _remove_bonus(context: SkillContext) -> void:
	var context_key := _get_context_key(context)

	if context.stats_controller != null:
		context.stats_controller.clear_effect_modifiers(_get_stats_effect_key(context))
	stats_applied.erase(context_key)

	var status_controller := _get_status_controller(context)
	if status_controller != null and armor_status != null:
		status_controller.remove_status_source(armor_status.id, _get_armor_effect_key(context))
	armor_applied.erase(context_key)


func _build_stat_modifiers(context: SkillContext) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for stat_name in full_equipment_stats.keys():
		var amount := float(full_equipment_stats[stat_name])
		if amount != 0.0:
			result.append(Modifier.create_flat(StringName(stat_name), amount, _get_stats_effect_key(context)))
	return result


func _is_equipment_full(context: SkillContext) -> bool:
	if context.player_build == null or context.player_build.player_equipment == null:
		return false

	var equipment := context.player_build.player_equipment
	if equipment.equip_slots.is_empty():
		return false

	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			return false

	return true


func _get_status_controller(context: SkillContext) -> StatusController:
	if context.status_controller != null:
		return context.status_controller
	if context.caster != null and context.caster.has_method("get_status_controller"):
		return context.caster.get_status_controller()
	if context.skill_controller != null:
		return context.skill_controller.get_node_or_null("../StatusController") as StatusController
	return null


func _get_source_node(context: SkillContext) -> Node:
	if context.caster != null:
		return context.caster
	return context.skill_controller


func _get_context_key(context: SkillContext) -> String:
	var owner_id := 0
	if context.skill_controller != null:
		owner_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(owner_id), str(context.effect_key)]


func _get_stats_effect_key(context: SkillContext) -> StringName:
	return StringName("%s_stats" % String(context.effect_key))


func _get_armor_effect_key(context: SkillContext) -> StringName:
	return StringName("%s_armor" % String(context.effect_key))
