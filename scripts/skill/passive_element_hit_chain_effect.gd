## 累计指定元素的有效技能命中后连锁其他敌人；连锁伤害不会递归触发技能被动。
class_name PassiveElementHitChainEffect
extends PassiveCombatListenerEffect

@export var required_element: StringName = &"lightning"
@export var hits_required: int = 3
@export var chain_count: int = 1
@export var chain_radius: float = 120.0
@export var damage: float = 10.0
@export var damage_types: Array[int] = [DamageData.DamageType.LIGHTNING]
@export var scaling_rule: DamageScalingRule
@export var hit_status: StatusData
@export var status_stacks: int = 1


func _create_listener() -> SkillCombatListener:
	return ElementHitChainListener.new()
