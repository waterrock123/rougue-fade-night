## 对 AbilityContext.targets 中的实体造成一次 DamageData 伤害。支持暴击、伤害类型、标签和属性成长公式。
class_name AbilityDealDamage
extends AbilityComponent

@export var damage: float = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["skill"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
## 普通直接攻击默认造成 12 点削韧；持续或纯效果伤害应在场景中改为 0。
@export var poise_damage: float = 12.0


# 对当前上下文中的目标逐个造成伤害。
# 这里负责创建 DamageData，并把“这次攻击的成长公式”一起塞进去。
func _activate(context: AbilityContext):
	if context == null or not context.is_caster_action_valid():
		return
	var targets = context.targets
	for target in targets:
		if not context.is_caster_action_valid():
			return
		if target != null and target is Entity:
			var damage_data := DamageData.create(
				damage,
				damage_types,
				tags,
				context.caster,
				target,
				can_crit,
				scaling_rule,
				context.ability.id if context.ability != null else &"",
				context.ability.runtime_slot_index if context.ability != null else -1,
				poise_damage
			)
			target.apply_damage(damage_data)

			for child in get_children():
				child.activate(context)
