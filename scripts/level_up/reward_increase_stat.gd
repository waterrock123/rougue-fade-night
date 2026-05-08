class_name RewardIncreaseStat
extends LevelUpReward

@export var stat_name: StringName
@export var amount: float = 1.0


func apply(context: LevelUpRewardContext):
	if context == null or context.player_build == null or context.player_build.player_stats == null:
		return

	var stats_data := context.player_build.player_stats
	var current_value = float(stats_data.get(stat_name))
	stats_data.set(stat_name, current_value + amount)

	if context.stats_controller != null:
		context.stats_controller.bind_player_build(context.player_build)
