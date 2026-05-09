class_name LevelUpRewardPool
extends Resource

@export var rewards: Array[LevelUpReward] = []


func get_random_rewards(count: int = 3, context: LevelUpRewardContext = null) -> Array[LevelUpReward]:
	var candidates := rewards.duplicate()
	candidates.shuffle()

	var result: Array[LevelUpReward] = []
	for reward in candidates:
		if reward == null:
			continue
		# 奖励自己决定当前局面下能不能出现，例如已拥有的技能奖励会被过滤掉。
		if not reward.is_available(context):
			continue
		result.append(reward)
		if result.size() >= count:
			break

	return result
