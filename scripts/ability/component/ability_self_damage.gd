## 自伤组件。
## 让施法者对自己造成一次 DamageData 伤害，适合狂兽冲撞、自爆、献祭等技能。
class_name AbilitySelfDamage
extends AbilityComponent

@export var damage: float = 5.0
@export var can_crit: bool = false
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["skill", "self_damage"]


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		return
	if damage <= 0.0:
		return

	var damage_data: DamageData = DamageData.create(
		damage,
		damage_types,
		tags,
		context.caster,
		context.caster,
		can_crit,
		null,
		context.ability.id if context.ability != null else &"",
		context.ability.runtime_slot_index if context.ability != null else -1
	)
	context.caster.apply_damage(damage_data)
