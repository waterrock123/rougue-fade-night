## 有效暴击削减一个冷却最长的非基础技能；触发间隔独立于命中次数，防止多弹瞬间刷空冷却。
class_name PassiveCriticalCooldownEffect
extends PassiveCombatListenerEffect

@export var cooldown_seconds: float = 1.0
@export var trigger_interval: float = 0.6
@export var kill_status: StatusData


func _create_listener() -> SkillCombatListener:
	return CriticalCooldownListener.new()
