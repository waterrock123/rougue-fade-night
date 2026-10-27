class_name CriticalCooldownListener
extends SkillCombatListener

var interval_remaining: float = 0.0


func _bind_signals() -> void:
	caster.damage_dealt.connect(_on_hit)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _unbind_signals() -> void:
	if is_instance_valid(caster) and caster.damage_dealt.is_connected(_on_hit):
		caster.damage_dealt.disconnect(_on_hit)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _process(delta: float) -> void:
	interval_remaining = maxf(interval_remaining - delta, 0.0)


func _on_hit(data: DamageData) -> void:
	if not _ready_for_event() or data == null or data.source != caster or not data.is_crit:
		return
	if not data.allow_skill_procs or data.final_damage <= 0.0 or interval_remaining > 0.0:
		return
	if not is_instance_valid(data.target) or not data.target.is_in_group("enemy"):
		return
	var ability: Ability = _longest_cooldown()
	if ability == null:
		return
	interval_remaining = maxf(float(config.get("trigger_interval")), 0.0)
	controller.reduce_remaining_cooldown_seconds(ability, float(config.get("cooldown_seconds")))


func _longest_cooldown() -> Ability:
	var longest: float = 0.0
	var result: Ability
	for ability: Ability in controller.abilities:
		if not is_instance_valid(ability) or controller.is_basic_ability(ability):
			continue
		var remaining: float = float(controller.cooldowns.get(ability, 0.0))
		if remaining > longest:
			longest = remaining
			result = ability
	return result


func _on_enemy_killed(_enemy: Entity, killer: Entity) -> void:
	var status: StatusData = config.get("kill_status") as StatusData
	if not _ready_for_event() or killer != caster or status == null:
		return
	if is_instance_valid(caster.status_controller):
		caster.status_controller.add_status(status, caster, source_key)


func _reset_state() -> void:
	interval_remaining = 0.0
	var status: StatusData = config.get("kill_status") as StatusData
	if is_instance_valid(caster) and is_instance_valid(caster.status_controller) and status != null:
		caster.status_controller.remove_status_source(status.id, source_key)
