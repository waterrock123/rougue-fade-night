## 只管理施法联动的绑定、解绑和战斗边界；具体规则由各监听器分工实现。
class_name SkillCombatListener
extends Node

var config: Resource
var caster: Entity
var controller: AbilityController
var source_key: String
var bound: bool = false
var battle_enabled: bool = false


func bind(settings: Resource, context: SkillContext) -> void:
	config = settings
	caster = context.caster
	controller = context.ability_controller
	source_key = str(context.effect_key)
	bound = true
	battle_enabled = EventBus.is_battle_active
	EventBus.battle_started.connect(_battle_started)
	EventBus.battle_rewards_resolving.connect(_battle_ended)
	EventBus.battle_lost.connect(_battle_ended)
	_bind_signals()


func stop() -> void:
	if not bound:
		return
	bound = false
	_battle_ended()
	_unbind_signals()
	EventBus.battle_started.disconnect(_battle_started)
	EventBus.battle_rewards_resolving.disconnect(_battle_ended)
	EventBus.battle_lost.disconnect(_battle_ended)


func _battle_started() -> void:
	_reset_state()
	battle_enabled = true


func _battle_ended() -> void:
	battle_enabled = false
	_reset_state()


func _exit_tree() -> void:
	stop()


func _ready_for_event() -> bool:
	return bound and battle_enabled and is_instance_valid(caster) and not caster.is_dead


func _eligible_cast(context: AbilityContext) -> bool:
	return _ready_for_event() and context != null and context.caster == caster and not context.cast_record.is_basic_attack


func _eligible_hit(data: DamageData) -> bool:
	if not _ready_for_event() or data == null or not data.allow_skill_procs or data.final_damage <= 0.0:
		return false
	if data.cast_record == null or data.cast_record.is_basic_attack or data.source != caster:
		return false
	# 地图物体可覆盖阵营方法以接受玩家攻击，但不应计入“命中敌人”的被动。
	return is_instance_valid(data.target) and data.target.is_in_group("enemy")


func _bind_signals() -> void:
	pass


func _unbind_signals() -> void:
	pass


func _reset_state() -> void:
	pass
