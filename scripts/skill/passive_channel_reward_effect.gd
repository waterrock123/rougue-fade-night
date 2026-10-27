## 成功吟唱后获得护甲状态和一次性施法优惠；打断不奖励，相同来源刷新而不叠加。
class_name PassiveChannelRewardEffect
extends PassiveCombatListenerEffect

@export var armor_status: StatusData
@export var next_energy_reduction: float = 5.0
@export var next_damage_multiplier: float = 1.0


func _create_listener() -> SkillCombatListener:
	return ChannelRewardListener.new()
