## 不同元素交替施法时返还能量并强化当前这次技能，不改变技能共享资源。
class_name PassiveElementRotationEffect
extends PassiveCombatListenerEffect

@export var energy_refund: float = 3.0
@export var damage_bonus: float = 0.2


func _create_listener() -> SkillCombatListener:
	return ElementRotationListener.new()
