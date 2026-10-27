class_name MaterialBasicAttackListener
extends SkillCombatListener

var remaining_attacks: int = 0
var first_attack: bool = false


func _bind_signals() -> void:
	controller.cast_prepared.connect(_on_cast)


func _unbind_signals() -> void:
	if is_instance_valid(controller) and controller.cast_prepared.is_connected(_on_cast):
		controller.cast_prepared.disconnect(_on_cast)


func _on_cast(context: AbilityContext) -> void:
	if not _ready_for_event() or context.caster != caster:
		return
	if not context.cast_record.is_basic_attack:
		var paid: int = int(context.cast_record.material_payments.get(config.get("material_tag_name"), 0))
		if paid > 0:
			remaining_attacks = maxi(int(config.get("attack_count")), 0)
			first_attack = true
			_sync_status()
		return
	if remaining_attacks <= 0:
		return
	context.cast_record.damage_multiplier *= 1.0 + float(config.get("damage_bonus"))
	if first_attack:
		context.cast_record.projectile_count_bonus += maxi(int(config.get("first_attack_extra_projectiles")), 0)
	first_attack = false
	remaining_attacks -= 1
	_sync_status()


func _sync_status() -> void:
	var status: StatusData = config.get("charges_status") as StatusData
	if status == null or not is_instance_valid(caster.status_controller):
		return
	if remaining_attacks > 0:
		caster.status_controller.add_status(status, caster, source_key, remaining_attacks)
	else:
		caster.status_controller.remove_status_source(status.id, source_key)


func _reset_state() -> void:
	remaining_attacks = 0
	first_attack = false
	if is_instance_valid(caster):
		_sync_status()
