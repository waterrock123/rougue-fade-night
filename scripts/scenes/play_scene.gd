class_name PlayScene
extends Node

const REST_PERIOD_SCENE := preload("res://scenes/rest_period/rest_period.tscn")

@export var screen_transition: ColorRect
@export var player_health_bar: PlayerHealthBar
@export var pause_menu: PauseMenu
@export var run_stats: RunStats

var player: Player

@onready var enemy_spawner: EnemySpawner = $EnemySpawner


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

	player.player_died.connect(_handle_game_over)
	if enemy_spawner != null:
		enemy_spawner.battle_completed.connect(_handle_battle_completed)

	AudioController.play_bg_music("battle")
	EventBus.game_paused.connect(_handle_pause)


# 玩家战败后的处理。
# 当前逻辑还是原来的“原地复活”流程，没有结束这一局。
func _handle_game_over(dead_player: Player) -> void:
	var tween:Tween = fade_in_overlay()
	await tween.finished
	dead_player.position = dead_player.spawn_location

	tween = await fade_out_overlay()
	await tween.finished

	dead_player.current_health = dead_player.max_health
	dead_player.current_energy = dead_player.max_energy
	if dead_player.stats_controller != null:
		dead_player.stats_controller.current_health = dead_player.current_health
		dead_player.stats_controller.current_energy = dead_player.current_energy

	dead_player.is_dead = false
	EventBus.player_health_changed.emit(dead_player.current_health, dead_player.max_health)


# 当 EnemySpawner 判断整场战斗已经完成时触发。
# 这里会先把当前玩家状态写回构筑数据，再切去修整期。
func _handle_battle_completed() -> void:
	_sync_player_build_state()
	var tween:Tween = fade_in_overlay()
	await tween.finished

	var run := _get_run()
	if run != null:
		run.change_to_rest_period()
		return

	EventBus.scene_changed.emit("rest_period")
	get_tree().change_scene_to_packed(REST_PERIOD_SCENE)


# 屏幕淡出。
func fade_out_overlay():
	var tween := create_tween()
	tween.tween_property(
		screen_transition,
		"color:a",
		0.0,
		1.0
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	return tween


# 屏幕淡入。
func fade_in_overlay():
	var tween := create_tween()
	tween.tween_property(
		screen_transition,
		"color:a",
		1.0,
		1.0
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	return tween


func _on_pause_btn_pressed() -> void:
	EventBus.game_paused.emit(true)
	EventBus.change_bag.emit()
	pause_menu.show()
	get_tree().paused = true


# 响应全局暂停状态，更新遮罩透明度。
func _handle_pause(paused: bool) -> void:
	if paused:
		screen_transition.color = Color(0, 0, 0, 0.5)
	else:
		screen_transition.color = Color(0, 0, 0, 0)


# 把当前战斗中玩家的生命和能量状态写回 run_stats.player_build。
# 这样进入修整期时看到的是这场战斗结束后的真实状态。
func _sync_player_build_state() -> void:
	if run_stats == null or run_stats.player_build == null or player == null:
		return

	run_stats.player_build.current_health = player.current_health
	run_stats.player_build.current_energy = player.current_energy


# 向上查找当前 PlayScene 是否挂在 Run 节点下面。
# 如果在 Run 里，就优先走 Run 的切场景流程来保留这局数据。
func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()

	return null
