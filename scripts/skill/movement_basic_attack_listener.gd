class_name MovementBasicAttackListener
extends SkillCombatListener

var move_time: float = 0.0
var shot_ready: bool = false


func _bind_signals() -> void:
	controller.cast_prepared.connect(_on_cast)


func _unbind_signals() -> void:
	if is_instance_valid(controller) and controller.cast_prepared.is_connected(_on_cast):
		controller.cast_prepared.disconnect(_on_cast)


func _process(delta: float) -> void:
	if not _ready_for_event() or shot_ready:
		return
	# 只接受玩家实际移动且有自主输入；站着顶墙、纯击退、冰面自然滑行均不积累。
	var moving: bool = bool(caster.get("is_moving")) and bool(caster.get("has_movement_input"))
	_advance_movement(delta, moving)


func _advance_movement(delta: float, moving: bool) -> void:
	if not moving:
		move_time = 0.0
		return
	move_time += maxf(delta, 0.0)
	if move_time >= maxf(float(config.get("move_seconds")), 0.01):
		shot_ready = true
		_apply_status(config.get("ready_status") as StatusData)


func _on_cast(context: AbilityContext) -> void:
	if not _ready_for_event() or context.caster != caster or not shot_ready:
		return
	if not context.cast_record.is_basic_attack:
		return
	context.cast_record.damage_multiplier *= 1.0 + float(config.get("damage_bonus"))
	shot_ready = false
	move_time = 0.0
	_remove_status(config.get("ready_status") as StatusData)
	_apply_status(config.get("after_attack_status") as StatusData)


func _apply_status(status: StatusData) -> void:
	if status != null and is_instance_valid(caster.status_controller):
		caster.status_controller.add_status(status, caster, source_key)


func _remove_status(status: StatusData) -> void:
	if status != null and is_instance_valid(caster) and is_instance_valid(caster.status_controller):
		caster.status_controller.remove_status_source(status.id, source_key)


func _reset_state() -> void:
	move_time = 0.0
	shot_ready = false
	_remove_status(config.get("ready_status") as StatusData)
	_remove_status(config.get("after_attack_status") as StatusData)
