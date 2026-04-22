class_name PlayerBuildProxy
extends Node

@export var player_build: PlayerBuild

@onready var stats_controller: StatsController = $StatsController
@onready var relic_controller: RelicController = $RelicController


func _ready() -> void:
	_resolve_player_build()
	if player_build == null:
		return

	if stats_controller != null:
		stats_controller.bind_player_build(player_build)

	if relic_controller != null:
		relic_controller.player_build = player_build
		relic_controller.equipment_inventory = player_build.player_equipment
		relic_controller.refresh_all()


func get_stats_controller() -> StatsController:
	return stats_controller


# 优先从父 RestPeriod 的 run_stats 中拿 player_build。
# 这样后面接入统一的 run 节点时，这里不用再改结构。
func _resolve_player_build() -> void:
	var rest_period := get_parent()
	if rest_period == null:
		return

	if "run_stats" in rest_period:
		var run_stats = rest_period.run_stats
		if run_stats != null and run_stats.player_build != null:
			player_build = run_stats.player_build
			return
