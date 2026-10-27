class_name AbilityContext
extends RefCounted

var caster: Entity
var ability: Ability
var targets: Array[Variant] = []
## 释放时的元素快照。投射物飞出后不再反查可能已经移除或重建的Ability。
var element_tags: Array[StringName] = []
var cast_record: AbilityCastRecord = AbilityCastRecord.new()
# 技能释放时锁定的方向。用于 Boss 预警和延迟伤害保持一致。
var locked_direction: Vector2 = Vector2.ZERO
## 本次释放的基础伤害倍率与齐射数量快照，不修改共享场景或技能资源。
var projectile_damage_multiplier: float = 1.0
var projectile_count_override: int = 0
## 松开按键时记录的蓄力比例；取消预览不会传入正式释放。
var charge_ratio: float = 0.0
# 创建上下文时记录施法者动作版本，施法者死亡或取消动作后，旧上下文会自动失效。
var caster_action_version: int = 0


func _init(_caster: Entity, _ability: Ability) -> void:
	caster = _caster
	ability = _ability
	if is_instance_valid(ability):
		element_tags = ability.get_element_tags()
		cast_record.is_basic_attack = ability.skill_data.is_basic_attack if ability.skill_data != null else ability.runtime_slot_index == 0
	if caster != null and caster.has_method("get_action_version"):
		caster_action_version = caster.get_action_version()


func has_element_tag(tag: StringName) -> bool:
	return SkillElementTags.has_tag(element_tags, tag)


func matches_element_tags(required: Array[StringName], require_all: bool = false) -> bool:
	return SkillElementTags.matches(element_tags, required, require_all)


## 直接伤害组件调用；与伤害类型和普通tags分开，不推断或改变元素伤害。
func stamp_damage_elements(data: DamageData) -> void:
	if data != null:
		data.skill_element_tags = element_tags.duplicate()
		data.cast_record = cast_record
		data.skill_damage_multiplier = cast_record.damage_multiplier


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
