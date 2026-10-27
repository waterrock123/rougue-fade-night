class_name ElementHitChainListener
extends SkillCombatListener

var hit_count: int = 0


func _bind_signals() -> void:
	caster.damage_dealt.connect(_on_hit)


func _unbind_signals() -> void:
	if is_instance_valid(caster) and caster.damage_dealt.is_connected(_on_hit):
		caster.damage_dealt.disconnect(_on_hit)


func _reset_state() -> void:
	hit_count = 0


func _on_hit(data: DamageData) -> void:
	if not _eligible_hit(data) or not data.has_skill_element(config.get("required_element")):
		return
	hit_count += 1
	var required: int = maxi(int(config.get("hits_required")), 1)
	if hit_count < required:
		return
	hit_count %= required
	if data.cast_record.claim_once(source_key):
		_chain_from(data.target)


func _chain_from(first_target: Entity) -> void:
	var origin: Vector2 = first_target.global_position
	var visited: Array[int] = [first_target.get_instance_id()]
	for i: int in range(maxi(int(config.get("chain_count")), 1)):
		if not _ready_for_event():
			return
		var candidates: Array[Entity] = SkillCombatQuery.enemies_within(caster, origin, float(config.get("chain_radius")), visited)
		if candidates.is_empty():
			return
		var target: Entity = candidates[0]
		visited.append(target.get_instance_id())
		var destination: Vector2 = target.global_position
		SkillCombatQuery.show_link(caster, origin, destination, Color(0.75, 0.85, 1.0))
		_damage_target(target)
		origin = destination


func _damage_target(target: Entity) -> void:
	var types: Array[int] = []
	types.assign(config.get("damage_types"))
	var rule: DamageScalingRule = config.get("scaling_rule") as DamageScalingRule
	var data: DamageData = DamageData.create(float(config.get("damage")), types, ["skill_proc", "chain"], caster, target, true, rule)
	data.allow_skill_procs = false
	target.apply_damage(data)
	var status: StatusData = config.get("hit_status") as StatusData
	if is_instance_valid(target) and not target.is_dead and status != null and data.final_damage > 0.0:
		if is_instance_valid(target.status_controller):
			target.status_controller.add_status(status, caster, source_key, int(config.get("status_stacks")))
