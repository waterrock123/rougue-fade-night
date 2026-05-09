class_name PassiveFullEquipmentArmorEffect
extends PassiveSkillEffect

# 装备栏全部填满时获得的状态。默认使用通用护甲状态，方便和装备护甲叠层。
@export var armor_status: StatusData = preload("res://status/armor.tres")
@export var armor_stacks: int = 2

var active_contexts: Dictionary = {}
var applied_keys: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.effect_key == null:
		return

	var context_key := _get_context_key(context)
	active_contexts[context_key] = context

	if not EventBus.equipment_update.is_connected(_on_equipment_update):
		EventBus.equipment_update.connect(_on_equipment_update)

	_refresh_context(context)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	var context_key := _get_context_key(context)
	_remove_armor(context)
	active_contexts.erase(context_key)
	applied_keys.erase(context_key)

	if active_contexts.is_empty() and EventBus.equipment_update.is_connected(_on_equipment_update):
		EventBus.equipment_update.disconnect(_on_equipment_update)


func _on_equipment_update() -> void:
	for value in active_contexts.values():
		var context := value as SkillContext
		if context == null:
			continue
		_refresh_context(context)


func _refresh_context(context: SkillContext) -> void:
	if _is_equipment_full(context):
		_apply_armor(context)
	else:
		_remove_armor(context)


func _apply_armor(context: SkillContext) -> void:
	var context_key := _get_context_key(context)
	if applied_keys.has(context_key):
		return

	var status_controller := _get_status_controller(context)
	if status_controller == null or armor_status == null:
		return

	status_controller.add_status(armor_status, _get_source_node(context), context.effect_key, armor_stacks)
	applied_keys[context_key] = true


func _remove_armor(context: SkillContext) -> void:
	var context_key := _get_context_key(context)
	applied_keys.erase(context_key)

	var status_controller := _get_status_controller(context)
	if status_controller == null or armor_status == null:
		return

	status_controller.remove_status_source(armor_status.id, context.effect_key)


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
