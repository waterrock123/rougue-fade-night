class_name PlayScene
extends Node

const REST_PERIOD_SCENE := preload("res://scenes/rest_period/rest_period.tscn")

@export var screen_transition: ColorRect
@export var player_health_bar: PlayerHealthBar
@export var pause_menu: PauseMenu
@export var run_stats: RunStats

var player: Player
var pending_battle_stats: BattleStats

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var spell_bar: SpellBar = $CanvasLayer/UI/SpellBar
@onready var passive_skill_bar: PassiveSkillBar = $CanvasLayer/UI/PassiveSkillBar


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if run_stats != null and run_stats.player_build != null and player != null:
		player.bind_player_build(run_stats.player_build)
	_refresh_skill_ui()

	if enemy_spawner != null and pending_battle_stats != null:
		enemy_spawner.battle_stats = pending_battle_stats

	if player != null and not player.player_died.is_connected(_handle_game_over):
		player.player_died.connect(_handle_game_over)
	if enemy_spawner != null:
		enemy_spawner.battle_completed.connect(_handle_battle_completed)

	AudioController.play_bg_music("battle")
	EventBus.game_paused.connect(_handle_pause)


func setup_run_battle(new_run_stats: RunStats, battle_stats: BattleStats) -> void:
	run_stats = new_run_stats
	pending_battle_stats = battle_stats

	var scene_player := get_node_or_null("Player") as Player
	if scene_player != null and run_stats != null and run_stats.player_build != null:
		scene_player.stats_data = run_stats.player_build.player_stats
		scene_player.player_inventory = run_stats.player_build.player_inventory
		scene_player.player_equipment = run_stats.player_build.player_equipment

	var spawner := get_node_or_null("EnemySpawner") as EnemySpawner
	if spawner != null:
		spawner.battle_stats = battle_stats


# 玩家战败后的处理。
# 玩家死亡后不再原地复活，而是交给 Run 打开死亡界面。
func _handle_game_over(dead_player: Player) -> void:
	var tween:Tween = fade_in_overlay()
	await tween.finished
	_sync_player_build_state()
	EventBus.battle_lost.emit()


# 当 EnemySpawner 判断整场战斗已经完成时触发。
# 这里会先把当前玩家状态写回构筑数据，再切去修整期。
func _handle_battle_completed() -> void:
	_restore_health_after_battle()
	_sync_player_build_state()
	var tween:Tween = fade_in_overlay()
	await tween.finished
	
	
	EventBus.battle_rewards_resolving.emit()
	EventBus.battle_win.emit()
	#var run := _get_run()
	#if run != null:
		#run.change_to_rest_period()
		#
		#return
#
	#EventBus.scene_changed.emit("rest_period")


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


# 每场战斗胜利后，按照当前体质点数恢复生命值。
func _restore_health_after_battle() -> void:
	if player == null or player.stats_controller == null:
		return

	var heal_amount := player.stats_controller.get_stat(&"constitution")
	if heal_amount <= 0.0:
		return

	player.current_health = min(player.current_health + heal_amount, player.max_health)
	player.stats_controller.current_health = player.current_health
	player.stats_controller.sync_runtime_resources()
	EventBus.player_health_changed.emit(player.current_health, player.max_health)


# 进入战斗时刷新主动技能栏与被动技能栏，保证 UI 使用本局 PlayerBuild 的技能数据。
func _refresh_skill_ui() -> void:
	if player != null and spell_bar != null and player.ability_controller != null:
		spell_bar.refresh_from_controller(player.ability_controller)

	if passive_skill_bar != null:
		var player_build := run_stats.player_build if run_stats != null else null
		passive_skill_bar.refresh_from_player_build(player_build)


# 向上查找当前 PlayScene 是否挂在 Run 节点下面。
# 如果在 Run 里，就优先走 Run 的切场景流程来保留这局数据。
func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()

	return null
