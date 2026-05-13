class_name UseSelfDamageEffect
extends RelicEffect

@export var damage: float = 1.0
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["consumable", "self_damage"]


# 使用消耗品时对使用者自己造成伤害。
# 这个效果只负责“自伤”这一件事，可以复用于带有代价的药水、食物、诅咒物等。
func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if damage <= 0.0:
		return

	var owner := relic_context.owner as Entity
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		null,
		owner,
		false
	)
	owner.apply_damage(damage_data)
