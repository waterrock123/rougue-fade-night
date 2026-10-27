class_name ElementHitStatusListener
extends SkillCombatListener


func _bind_signals() -> void:
	caster.damage_dealt.connect(_on_hit)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _unbind_signals() -> void:
	if is_instance_valid(caster) and caster.damage_dealt.is_connected(_on_hit):
		caster.damage_dealt.disconnect(_on_hit)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _on_hit(data: DamageData) -> void:
	if not _eligible_hit(data) or not data.has_skill_element(config.get("required_element")):
		return
	if data.target.current_health <= 0.0 or not data.cast_record.claim_once(source_key, data.target.get_instance_id()):
		return
	_apply_status(data.target, int(config.get("hit_stacks")))


func _apply_status(target: Entity, stacks: int) -> void:
	var status: StatusData = config.get("hit_status") as StatusData
	if status != null and is_instance_valid(target.status_controller):
		target.status_controller.add_status(status, caster, _status_key(), stacks)


func _status_key() -> String:
	return "%s_%d" % [source_key, caster.get_instance_id()]


func _on_enemy_killed(enemy: Entity, _killer: Entity) -> void:
	if not _ready_for_event() or not bool(config.get("spread_on_death")) or not is_instance_valid(enemy):
		return
	var status: StatusData = config.get("hit_status") as StatusData
	if status == null or not is_instance_valid(enemy.status_controller):
		return
	var instance: StatusInstance = enemy.status_controller.get_status(status.id)
	# 只传播该玩家提供的燃烧，避免多人共斗时借别人的状态无限扩散。
	if instance == null or not instance.source_stacks.has(_status_key()):
		return
	for target: Entity in SkillCombatQuery.enemies_within(caster, enemy.global_position, float(config.get("spread_radius")), [enemy.get_instance_id()]):
		_apply_status(target, int(config.get("spread_stacks")))
