class_name ChannelRewardListener
extends SkillCombatListener


func _bind_signals() -> void:
	controller.channel_completed.connect(_on_channel_completed)


func _unbind_signals() -> void:
	if is_instance_valid(controller) and controller.channel_completed.is_connected(_on_channel_completed):
		controller.channel_completed.disconnect(_on_channel_completed)


func _reset_state() -> void:
	if is_instance_valid(controller):
		controller.clear_next_cast_modifier(source_key)
	var status: StatusData = config.get("armor_status") as StatusData
	if is_instance_valid(caster) and is_instance_valid(caster.status_controller) and status != null:
		caster.status_controller.remove_status_source(status.id, source_key)


func _on_channel_completed(context: AbilityContext) -> void:
	if not _eligible_cast(context):
		return
	var status: StatusData = config.get("armor_status") as StatusData
	if status != null and is_instance_valid(caster.status_controller):
		caster.status_controller.add_status(status, caster, source_key)
	controller.set_next_cast_modifier(source_key, {
		"energy_reduction": maxf(float(config.get("next_energy_reduction")), 0.0),
		"damage_multiplier": maxf(float(config.get("next_damage_multiplier")), 0.0),
	})
