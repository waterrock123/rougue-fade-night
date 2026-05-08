class_name PlayerBuildProxy
extends Node

@export var player_build: PlayerBuild

@onready var stats_controller: StatsController = $StatsController
@onready var relic_controller: RelicController = $RelicController
@onready var skill_controller: SkillController = $SkillController


func _ready() -> void:
	_resolve_player_build()
	if player_build == null:
		return

	bind_player_build(player_build)


func bind_player_build(new_player_build: PlayerBuild) -> void:
	player_build = new_player_build
	if player_build == null:
		return

	if stats_controller != null:
		stats_controller.bind_player_build(player_build)

	if relic_controller != null:
		relic_controller.player_build = player_build
		relic_controller.equipment_inventory = player_build.player_equipment
		relic_controller.refresh_all()

	if skill_controller != null:
		skill_controller.bind_player_build(player_build)


func get_stats_controller() -> StatsController:
	return stats_controller


func get_skill_controller() -> SkillController:
	return skill_controller


# 优先向上查找带 run_stats 的父节点，兼容 Run 和 RestPeriod 两种挂载方式。
func _resolve_player_build() -> void:
	var node := get_parent()
	while node != null:
		if "run_stats" in node:
			var resolved_run_stats = node.run_stats
			if resolved_run_stats != null and resolved_run_stats.player_build != null:
				player_build = resolved_run_stats.player_build
				return
		node = node.get_parent()
