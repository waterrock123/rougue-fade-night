## 单个来源同时只标记一个敌人，记录单场赏金，不依赖Ability实例生命周期。
## 增伤仅登记到标记者自己的出伤属性，其他角色不会分享这15%加成。
class_name BountyMarkController
extends Node

var caster: Entity
var source_key: String
var target_ref: WeakRef
var current_status: StatusData
var remaining: float = 0.0
var reward_gold: int = 1
var reward_limit: int = 1
var gold_earned: int = 0
var rewarded_targets: Dictionary = {}
var mark_visual: Node2D
var bound: bool = false


func bind(source: Entity, key: String) -> void:
	caster = source
	source_key = key
	bound = true
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.battle_started.connect(_reset_battle)
	EventBus.battle_rewards_resolving.connect(_clear_mark)
	EventBus.battle_lost.connect(_clear_mark)


func mark(target: Entity, status: StatusData, seconds: float, bonus: float, gold: int, limit: int) -> void:
	_clear_mark()
	if not is_instance_valid(target) or not target.can_be_targeted():
		return
	target_ref = weakref(target)
	current_status = status
	remaining = maxf(seconds, 0.0)
	reward_gold = maxi(gold, 0)
	reward_limit = maxi(limit, 0)
	if is_instance_valid(caster.stats_controller):
		caster.stats_controller.set_outgoing_damage_bonus_modifier(source_key, {
			"required_target_id": target.get_instance_id(),
			"total_damage_percent_bonus": maxf(bonus, 0.0),
		})
	if status != null and is_instance_valid(target.status_controller):
		target.status_controller.add_status(status, caster, source_key, 1, remaining)
	mark_visual = BountyMarkVisual.new()
	target.add_child(mark_visual)
	mark_visual.position = Vector2(0, -28)


func _process(delta: float) -> void:
	if target_ref == null:
		return
	remaining -= delta
	if remaining <= 0.0 or _target() == null or not EventBus.is_battle_active:
		_clear_mark()


func _target() -> Entity:
	if target_ref == null:
		return null
	var value: Variant = target_ref.get_ref()
	return value as Entity if is_instance_valid(value) else null


func _on_enemy_killed(enemy: Entity, killer: Entity) -> void:
	if enemy != _target():
		return
	if killer == caster and remaining > 0.0 and not rewarded_targets.has(enemy.get_instance_id()):
		var stats: RunStats = _resolve_run_stats()
		var amount: int = mini(reward_gold, maxi(reward_limit - gold_earned, 0))
		if stats != null and amount > 0:
			stats.gold += amount
			gold_earned += amount
			rewarded_targets[enemy.get_instance_id()] = true
			FloatText.show_screen_tip("赏金标记：获得%d金币" % amount)
	_clear_mark()


func _resolve_run_stats() -> RunStats:
	if not is_instance_valid(caster):
		return null
	var skills: SkillController = caster.get_node_or_null("SkillController") as SkillController
	return skills.run_stats if skills != null else null


func _clear_mark() -> void:
	if is_instance_valid(caster) and is_instance_valid(caster.stats_controller):
		caster.stats_controller.clear_outgoing_damage_bonus_modifier(source_key)
	var target: Entity = _target()
	if target != null and current_status != null and is_instance_valid(target.status_controller):
		target.status_controller.remove_status_source(current_status.id, source_key)
	if is_instance_valid(mark_visual):
		mark_visual.queue_free()
	mark_visual = null
	target_ref = null
	current_status = null
	remaining = 0.0


func _reset_battle() -> void:
	_clear_mark()
	gold_earned = 0
	rewarded_targets.clear()


func _exit_tree() -> void:
	_clear_mark()
	if not bound:
		return
	EventBus.enemy_killed.disconnect(_on_enemy_killed)
	EventBus.battle_started.disconnect(_reset_battle)
	EventBus.battle_rewards_resolving.disconnect(_clear_mark)
	EventBus.battle_lost.disconnect(_clear_mark)
	bound = false
