class_name EnemySpawner
extends Node

signal wave_started(wave_index: int)
signal wave_spawn_finished(wave_index: int)
signal wave_cleared(wave_index: int)
signal battle_completed

@export var battle_stats: BattleStats
# 敌人围绕哪个节点附近生成，通常就是玩家。
@export var spawn_around: Node2D
@export var min_spawn_radius: float = 200.0
@export var max_spawn_radius: float = 500.0

var current_wave_index: int = -1
var current_wave_spawned: int = 0
var total_spawned: int = 0
var spawn_timer: float = 0.0
var next_wave_timer: float = 0.0
var waiting_for_next_wave: bool = false
var battle_finished: bool = false
var active_enemies: Array[Enemy] = []


func _ready() -> void:
	if battle_stats == null or battle_stats.get_wave_count() == 0:
		battle_finished = true
		call_deferred("_emit_battle_completed")
		return

	_start_wave(0)


func _process(delta: float) -> void:
	if battle_finished or battle_stats == null:
		return

	if waiting_for_next_wave:
		_process_next_wave(delta)
		return

	var wave_data := _get_current_wave_data()
	if wave_data == null:
		_try_finish_battle()
		return

	if current_wave_spawned >= wave_data.max_enemies:
		_begin_wait_for_next_wave()
		return

	spawn_timer += delta
	while spawn_timer >= wave_data.spawn_interval and current_wave_spawned < wave_data.max_enemies:
		spawn_timer -= wave_data.spawn_interval
		_spawn_enemy_batch(wave_data)

		if current_wave_spawned >= wave_data.max_enemies:
			emit_signal("wave_spawn_finished", current_wave_index)
			_begin_wait_for_next_wave()
			break


# 获取当前正在处理的波次数据。
func _get_current_wave_data() -> BattleWaveData:
	if battle_stats == null:
		return null
	return battle_stats.get_wave_data(current_wave_index)


# 启动指定波次，并重置这一波自己的计时状态。
func _start_wave(wave_index: int) -> void:
	current_wave_index = wave_index
	current_wave_spawned = 0
	spawn_timer = 0.0
	next_wave_timer = 0.0
	waiting_for_next_wave = false
	emit_signal("wave_started", current_wave_index)


# 按当前波次配置生成一批敌人。
# 这里会记录“这一波已经生成了多少”和“当前场上活着多少只”。
func _spawn_enemy_batch(wave_data: BattleWaveData) -> void:
	for _spawn_index in range(max(wave_data.spawn_batch_size, 1)):
		if current_wave_spawned >= wave_data.max_enemies:
			return

		var enemy := _spawn_enemy(wave_data)
		if enemy == null:
			return

		current_wave_spawned += 1
		total_spawned += 1
		active_enemies.append(enemy)
		enemy.tree_exited.connect(_on_spawned_enemy_exited.bind(enemy), CONNECT_ONE_SHOT)


# 实际实例化一只敌人，并把它放到玩家周围的随机位置。
func _spawn_enemy(wave_data: BattleWaveData) -> Enemy:
	if spawn_around == null or wave_data == null or wave_data.packed_enemies.is_empty():
		return null

	var enemy_scene: PackedScene = wave_data.packed_enemies.pick_random()
	if enemy_scene == null:
		return null

	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null

	var spawn_radius := randf_range(min_spawn_radius, max_spawn_radius)
	var rand_pos := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * spawn_radius
	var spawn_pos := spawn_around.global_position + rand_pos

	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
	return enemy


# 标记当前波次已经进入“等待下一波”阶段。
# 这时不再继续刷怪，只等待推进条件满足。
func _begin_wait_for_next_wave() -> void:
	if waiting_for_next_wave:
		return

	waiting_for_next_wave = true
	next_wave_timer = 0.0


# 根据波次的推进规则判断是否进入下一波。
# 如果已经是最后一波，就进一步检查战斗是否满足结束条件。
func _process_next_wave(delta: float) -> void:
	var wave_data := _get_current_wave_data()
	if wave_data == null:
		_try_finish_battle()
		return

	if wave_data.advance_mode == BattleWaveData.AdvanceMode.CLEAR_PREVIOUS and not active_enemies.is_empty():
		return

	next_wave_timer += delta
	if next_wave_timer < wave_data.next_wave_delay:
		return

	var next_wave_index := current_wave_index + 1
	if next_wave_index >= battle_stats.get_wave_count():
		_try_finish_battle()
		return

	_start_wave(next_wave_index)


# 监听由本生成器生成出来的敌人离场。
# 敌人死亡 queue_free 后会触发这里，用来更新场上剩余敌人数。
func _on_spawned_enemy_exited(enemy: Enemy) -> void:
	active_enemies.erase(enemy)

	var wave_data := _get_current_wave_data()
	if wave_data != null and current_wave_spawned >= wave_data.max_enemies and active_enemies.is_empty():
		emit_signal("wave_cleared", current_wave_index)

	_try_finish_battle()


# 战斗结束条件：
# 1. 已经来到最后一波
# 2. 最后一波的敌人已经全部生成完
# 3. 场上已经没有由本生成器生成的敌人存活
func _try_finish_battle() -> void:
	if battle_finished or battle_stats == null:
		return

	var is_last_wave := current_wave_index >= battle_stats.get_wave_count() - 1
	if not is_last_wave:
		return

	var wave_data := _get_current_wave_data()
	if wave_data == null:
		return

	if current_wave_spawned < wave_data.max_enemies:
		return

	if not active_enemies.is_empty():
		return

	battle_finished = true
	emit_signal("battle_completed")


# 给“空战斗”这种情况用的兜底触发。
func _emit_battle_completed() -> void:
	emit_signal("battle_completed")
