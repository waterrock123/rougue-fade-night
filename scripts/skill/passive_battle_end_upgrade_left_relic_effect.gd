class_name PassiveBattleEndUpgradeLeftRelicEffect
extends PassiveSkillEffect

# 战斗胜利后，如果装备栏全满，将最左侧一件未升级装备变为升级态。
# 这不是“三合一合成”，所以不会触发免费三选一奖励。
@export var require_full_equipment: bool = true

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
			_upgrade_left_unleveled_relic(context)


func _upgrade_left_unleveled_relic(context: SkillContext) -> void:
	var equipment := _get_equipment(context)
	if equipment == null:
		return
	if require_full_equipment and not _is_equipment_full(equipment):
		return

	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue
		if slot.item.leveltip != Relic.LevelTip.UNLEVELUP:
			continue

		slot.item.leveltip = Relic.LevelTip.LEVELUP
		AudioController.play_ui_sound(&"level_up_item")
		EventBus.equipment_update.emit()
		return


func _get_equipment(context: SkillContext) -> Equipment:
	if context.player_build == null:
		return null
	return context.player_build.player_equipment


func _is_equipment_full(equipment: Equipment) -> bool:
	if equipment.equip_slots.is_empty():
		return false
	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			return false
	return true


func _get_context_key(context: SkillContext) -> String:
	var owner_id := 0
	if context.skill_controller != null:
		owner_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(owner_id), str(context.effect_key)]
