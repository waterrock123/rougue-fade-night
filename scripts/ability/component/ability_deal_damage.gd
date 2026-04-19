class_name AbilityDealDamage
extends AbilityComponent

@export var damage: float = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["skill"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()


# 对当前上下文中的目标逐个造成伤害。
# 这里负责创建 DamageData，并把“这次攻击的成长公式”一起塞进去。
func _activate(context: AbilityContext):
	var targets = context.targets
	for target in targets:
		if target != null and target is Entity:
			var damage_data := DamageData.create(
				damage,
				damage_types,
				tags,
				context.caster,
				target,
				can_crit,
				scaling_rule
			)
			target.apply_damage(damage_data)

			for child in get_children():
				child.activate(context)
