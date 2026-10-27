## 元素技能命中后追加状态，每次施法对每个目标仅一次；可选死亡时传播自身施加的状态。
class_name PassiveElementHitStatusEffect
extends PassiveCombatListenerEffect

@export var required_element: StringName = &"fire"
@export var hit_status: StatusData
@export var hit_stacks: int = 1
@export var spread_on_death: bool = false
@export var spread_radius: float = 100.0
@export var spread_stacks: int = 2


func _create_listener() -> SkillCombatListener:
	return ElementHitStatusListener.new()
