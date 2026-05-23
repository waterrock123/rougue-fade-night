## 一次性套装效果：达成条件时永久修改 PlayerBuild 的基础属性。
class_name TagPermanentStatsOnceEffect
extends TagEffect

@export var stat_bonuses: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	if context == null or context.player_build == null or context.player_build.player_stats == null:
		return
	if context.is_once_completed():
		return

	_apply_stats(context.player_build.player_stats)
	if context.stats_controller != null:
		context.stats_controller.bind_player_build(context.player_build)
	context.mark_once_completed()
	EventBus.attribute_update.emit()


func _apply_stats(stats_data: StatsData) -> void:
	for stat_name in stat_bonuses.keys():
		var amount := int(stat_bonuses[stat_name])
		match StringName(stat_name):
			&"strength":
				stats_data.strength += amount
			&"dexterity":
				stats_data.dexterity += amount
			&"intelligence":
				stats_data.intelligence += amount
			&"constitution":
				stats_data.constitution += amount
			&"speed":
				stats_data.speed += amount
			&"charm":
				stats_data.charm += amount
			&"luck":
				stats_data.luck += amount
			&"base_damage_reduction_rate":
				stats_data.base_damage_reduction_rate += float(stat_bonuses[stat_name])
			&"base_static_damage_reduction":
				stats_data.base_static_damage_reduction += amount
