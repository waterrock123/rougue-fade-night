## 破韧只准备下一次普攻，强化快照跟随整次施法；溅射不再次触发技能联动。
class_name PoiseBreakBasicAttackListener
extends SkillCombatListener

var ready_remaining: float = 0.0
var cooldown_remaining: float = 0.0


func _bind_signals() -> void:
	controller.cast_prepared.connect(_on_cast)
	caster.damage_dealt.connect(_on_hit)
	EventBus.enemy_poise_broken.connect(_on_break)


func _unbind_signals() -> void:
	if is_instance_valid(controller) and controller.cast_prepared.is_connected(_on_cast):
		controller.cast_prepared.disconnect(_on_cast)
	if is_instance_valid(caster) and caster.damage_dealt.is_connected(_on_hit):
		caster.damage_dealt.disconnect(_on_hit)
	if EventBus.enemy_poise_broken.is_connected(_on_break):
		EventBus.enemy_poise_broken.disconnect(_on_break)


func _process(delta: float) -> void:
	if not _ready_for_event():
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if ready_remaining > 0.0:
		ready_remaining = maxf(ready_remaining - delta, 0.0)
		if ready_remaining <= 0.0:
			_remove_status()


func _on_break(enemy: Entity, breaker: Entity, data: DamageData) -> void:
	if not _ready_for_event() or breaker != caster or data == null or not data.allow_skill_procs:
		return
	if not is_instance_valid(enemy) or not enemy.is_in_group("enemy") or enemy.is_in_group("map_object"):
		return
	ready_remaining = maxf(float(config.get("ready_seconds")), 0.0)
	var status: StatusData = config.get("ready_status") as StatusData
	if status != null and is_instance_valid(caster.status_controller):
		caster.status_controller.add_status(status, caster, source_key, 1, ready_remaining)
	_reduce_cooldowns()


func _reduce_cooldowns() -> void:
	var seconds: float = float(config.get("cooldown_seconds"))
	if seconds <= 0.0 or cooldown_remaining > 0.0:
		return
	cooldown_remaining = maxf(float(config.get("cooldown_interval")), 0.0)
	for ability: Ability in controller.abilities:
		if is_instance_valid(ability) and not controller.is_basic_ability(ability):
			controller.reduce_remaining_cooldown_seconds(ability, seconds)


func _on_cast(context: AbilityContext) -> void:
	if not _ready_for_event() or context.caster != caster or ready_remaining <= 0.0:
		return
	if not context.cast_record.is_basic_attack:
		return
	context.cast_record.damage_multiplier *= 1.0 + float(config.get("damage_bonus"))
	context.cast_record.claim_once(source_key + ":empowered")
	ready_remaining = 0.0
	_remove_status()


func _on_hit(data: DamageData) -> void:
	if not _ready_for_event() or data == null or data.source != caster or data.final_damage <= 0.0:
		return
	if not data.allow_skill_procs or data.cast_record == null or not data.cast_record.is_basic_attack:
		return
	if not is_instance_valid(data.target) or not data.target.is_in_group("enemy") or data.target.is_in_group("map_object"):
		return
	if float(config.get("splash_strength_ratio")) <= 0.0 or not data.cast_record.claims.has(source_key + ":empowered:0"):
		return
	if not data.cast_record.claim_once(source_key + ":splash"):
		return
	_splash(data.target, data)


func _splash(primary: Entity, original: DamageData) -> void:
	var origin: Vector2 = primary.global_position
	var targets: Array[Entity] = SkillCombatQuery.enemies_within(caster, origin, float(config.get("splash_radius")), [primary.get_instance_id()])
	var rule: DamageScalingRule = DamageScalingRule.new()
	rule.physical_formula = "strength * %s" % str(float(config.get("splash_strength_ratio")))
	for target: Entity in targets:
		if not _ready_for_event() or not is_instance_valid(target) or not target.can_be_targeted() or target.is_in_group("map_object"):
			continue
		var data: DamageData = DamageData.create(0.0, [DamageData.DamageType.PHYSICAL], ["skill", "melee", "poise_splash"], caster, target, true, rule, original.source_ability_id, original.source_ability_slot_index)
		data.allow_skill_procs = false
		data.skill_element_tags = original.skill_element_tags.duplicate()
		data.impact_direction = origin.direction_to(target.global_position)
		target.apply_damage(data)


func _remove_status() -> void:
	var status: StatusData = config.get("ready_status") as StatusData
	if status != null and is_instance_valid(caster) and is_instance_valid(caster.status_controller):
		caster.status_controller.remove_status_source(status.id, source_key)


func _reset_state() -> void:
	ready_remaining = 0.0
	cooldown_remaining = 0.0
	_remove_status()
