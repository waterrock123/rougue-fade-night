## 实际支付指定材料后强化若干次基础攻击；整次攻击共用快照，多弹只扣一次次数。
class_name PassiveMaterialBasicAttackEffect
extends PassiveCombatListenerEffect

@export var material_tag_name: StringName = &"弹药"
@export var attack_count: int = 3
@export var damage_bonus: float = 0.25
@export var first_attack_extra_projectiles: int = 0
@export var charges_status: StatusData


func _create_listener() -> SkillCombatListener:
	return MaterialBasicAttackListener.new()
