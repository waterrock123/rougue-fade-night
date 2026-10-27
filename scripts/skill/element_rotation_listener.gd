class_name ElementRotationListener
extends SkillCombatListener

var previous_elements: Array[StringName] = []


func _bind_signals() -> void:
	controller.cast_prepared.connect(_on_cast)


func _unbind_signals() -> void:
	if is_instance_valid(controller) and controller.cast_prepared.is_connected(_on_cast):
		controller.cast_prepared.disconnect(_on_cast)


func _reset_state() -> void:
	previous_elements.clear()


func _on_cast(context: AbilityContext) -> void:
	if not _eligible_cast(context):
		return
	var qualifies: bool = is_different_rotation(previous_elements, context.element_tags)
	previous_elements = context.element_tags.duplicate()
	if not qualifies:
		return
	context.cast_record.damage_multiplier *= 1.0 + float(config.get("damage_bonus"))
	_refund_energy(float(config.get("energy_refund")))


## 多元素技能只有与前一个技能完全没有共同元素才算切换；无元素技能中断连段。
func is_different_rotation(previous: Array[StringName], current: Array[StringName]) -> bool:
	if previous.is_empty() or current.is_empty():
		return false
	for element: StringName in current:
		if previous.has(element):
			return false
	return true


func _refund_energy(amount: float) -> void:
	caster.current_energy = minf(caster.current_energy + maxf(amount, 0.0), caster.max_energy)
	if is_instance_valid(caster.stats_controller):
		caster.stats_controller.current_energy = caster.current_energy
		caster.stats_controller.sync_runtime_resources()
	if caster.is_in_group("player"):
		EventBus.player_energy_changed.emit(caster.current_energy, caster.max_energy)
