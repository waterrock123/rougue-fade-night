## 消耗品使用时对自己造成伤害的效果。
## 适合做带代价的药水、食物、诅咒物等效果。
class_name UseSelfDamageEffect
extends RelicEffect


## 对使用者造成的基础伤害。
@export var damage: float = 1.0
## 伤害类型数组，对应 DamageData.DamageType。
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
## 伤害标签，用于后续和修饰器、状态或判定逻辑联动。
@export var tags: Array[String] = ["consumable", "self_damage"]


## 使用消耗品时对使用者自己造成伤害。
## 这个效果只负责“自伤”这一件事，可以复用于带有代价的药水、食物、诅咒物等。
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
