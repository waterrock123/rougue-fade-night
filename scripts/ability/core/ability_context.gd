class_name AbilityContext
extends RefCounted

var caster: Entity
var ability: Ability
var targets: Array[Variant] = []
# 技能释放时锁定的方向。用于 Boss 预警和延迟伤害保持一致。
var locked_direction: Vector2 = Vector2.ZERO
# 创建上下文时记录施法者动作版本，施法者死亡或取消动作后，旧上下文会自动失效。
var caster_action_version: int = 0


func _init(_caster: Entity, _ability: Ability) -> void:
	caster = _caster
	ability = _ability
	if caster != null and caster.has_method("get_action_version"):
		caster_action_version = caster.get_action_version()


func get_target_positon(idx: int) -> Vector2:
	var target = targets[idx]
	if target is Entity:
		return target.global_position
	if target is Vector2:
		return target
	return Vector2.ZERO


func is_caster_action_valid() -> bool:
	if caster == null:
		return false
	if not is_instance_valid(caster):
		return false
	if caster.is_dead:
		return false
	if caster.has_method("get_action_version") and caster.get_action_version() != caster_action_version:
		return false
	return true
