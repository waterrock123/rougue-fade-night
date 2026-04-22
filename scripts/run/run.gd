class_name Run
extends Node

#战斗场景
const PLAY_SCENE: = preload("res://scenes/play_scene.tscn")
#修整场景
const REST_SCENE: = preload("res://scenes/rest_period/rest_period.tscn") 


@export var run_startup: RunStartup


@onready var current_view: Node = $CurrentView


var run_stats: RunStats
var character_stats: StatsData
var player_inventory:Inventory
var player_equipment:Equipment
var shop:Shop


# 进入 Run 时，把当前子场景先绑定一次 run_stats。
func _ready() -> void:
	var current_scene := _get_current_scene()
	if current_scene != null:
		_bind_run_stats(current_scene)


# 切到战斗场景。
func change_to_play_scene() -> void:
	_change_scene(PLAY_SCENE)


# 切到修整期场景。
func change_to_rest_period() -> void:
	_change_scene(REST_SCENE)


# Run 自己管理场景切换，这样同一份 run_stats 可以一直沿用下去。
func _change_scene(scene_resource: PackedScene) -> void:
	if scene_resource == null:
		return

	var current_scene := _get_current_scene()
	if current_scene != null:
		current_view.remove_child(current_scene)
		current_scene.queue_free()

	var next_scene := scene_resource.instantiate()
	current_view.add_child(next_scene)
	_bind_run_stats(next_scene)


# 如果目标场景暴露了 run_stats 字段，就把当前这局的数据注入进去。
func _bind_run_stats(scene: Node) -> void:
	if scene == null:
		return

	if "run_stats" in scene:
		scene.run_stats = run_stats


# 当前 Run 下实际正在显示的子场景。
func _get_current_scene() -> Node:
	if current_view.get_child_count() == 0:
		return null

	return current_view.get_child(0)
