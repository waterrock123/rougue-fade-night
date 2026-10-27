## 连续主动移动后强化下一次整次基础攻击，可选使用强化攻击后的限时状态。
class_name PassiveMovementBasicAttackEffect
extends PassiveCombatListenerEffect

@export var move_seconds: float = 1.0
@export var damage_bonus: float = 0.5
@export var ready_status: StatusData
@export var after_attack_status: StatusData


func _create_listener() -> SkillCombatListener:
	return MovementBasicAttackListener.new()
