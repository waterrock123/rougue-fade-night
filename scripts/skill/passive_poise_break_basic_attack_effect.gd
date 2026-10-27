## 本人破韧后准备一次限时普攻强化；升级可附带一次溅射或限频削减主动技能冷却。
## 效果资源仅保存配置，战斗状态由角色独立监听器管理。
class_name PassivePoiseBreakBasicAttackEffect
extends PassiveCombatListenerEffect

@export var damage_bonus: float = 0.4
@export var ready_seconds: float = 5.0
@export var ready_status: StatusData
@export var splash_radius: float = 75.0
@export var splash_strength_ratio: float = 0.0
@export var cooldown_seconds: float = 0.0
@export var cooldown_interval: float = 2.0


func _create_listener() -> SkillCombatListener:
	return PoiseBreakBasicAttackListener.new()
