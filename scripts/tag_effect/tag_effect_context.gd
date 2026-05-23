class_name TagEffectContext
extends RefCounted

var run_stats: RunStats
var player_build: PlayerBuild
var effect_owner: Node
var stats_controller: StatsController
var tag_effect_controller: TagEffectController
var tag_effect: TagEffect
var effect_key: String = ""
var tag_count: int = 0
var counted_relics: Array[Relic] = []


func _init(
	new_run_stats: RunStats,
	new_owner: Node,
	new_stats_controller: StatsController,
	new_tag_effect_controller: TagEffectController,
	new_tag_effect: TagEffect,
	new_effect_key: String,
	new_tag_count: int,
	new_counted_relics: Array[Relic]
) -> void:
	run_stats = new_run_stats
	player_build = run_stats.player_build if run_stats != null else null
	effect_owner = new_owner
	stats_controller = new_stats_controller
	tag_effect_controller = new_tag_effect_controller
	tag_effect = new_tag_effect
	effect_key = new_effect_key
	tag_count = new_tag_count
	counted_relics = new_counted_relics.duplicate()


# 标记一次性 tag 效果已经结算过，避免刷新装备、读档或进入战斗时重复触发。
func mark_once_completed() -> void:
	if run_stats == null or tag_effect == null:
		return

	run_stats.mark_tag_effect_once_completed(tag_effect.id)


func is_once_completed() -> bool:
	if run_stats == null or tag_effect == null:
		return false

	return run_stats.is_tag_effect_once_completed(tag_effect.id)
