class_name LevelUpRewardPool
extends Resource

@export var rewards: Array[LevelUpReward] = []


func get_random_rewards(count: int = 3) -> Array[LevelUpReward]:
	var candidates := rewards.duplicate()
	candidates.shuffle()

	var result: Array[LevelUpReward] = []
	for reward in candidates:
		if reward == null:
			continue
		result.append(reward)
		if result.size() >= count:
			break

	return result
