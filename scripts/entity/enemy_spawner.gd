class_name EnemySpawner
extends Node

const DEFAULT_BOUNTY_ENEMY_POOL := preload("res://custom_resource/default_bounty_enemy_pool.tres")

signal wave_started(wave_index: int)
signal wave_spawn_finished(wave_index: int)
signal wave_cleared(wave_index: int)
signal battle_completed
signal bounty_enemy_presence_changed(has_bounty_enemy: bool)

@export var battle_stats: BattleStats
# 敌人围绕哪个节点附近生成，通常就是玩家。
@export var spawn_around: Node2D
# 可选绑定战斗地图。未手动指定时，会自动从同级节点里寻找 BattleMap。
@export var battle_map: BattleMap
@export var min_spawn_radius: float = 200.0
@export var max_spawn_radius: float = 500.0
@export_group("悬赏精英怪")
## 每场战斗自然出现悬赏精英怪的概率。默认约 1.5%，可在具体场景里调成 1%-2%。
@export_range(0.0, 1.0, 0.001) var random_bounty_spawn_chance: float = 0.015
@export var enable_random_bounty_spawn: bool = true
@export var bounty_enemy_pool: BountyEnemyPool

var current_wave_index: int = -1
var current_wave_spawned: int = 0
var current_wave_total_to_spawn: int = 0
var total_spawned: int = 0
var spawn_timer: float = 0.0
var next_wave_timer: float = 0.0
var waiting_for_next_wave: bool = false
var battle_finished: bool = false
var active_enemies: Array[Enemy] = []
var active_bounty_enemies: Array[Enemy] = []
var current_wave_plan: Array[Dictionary] = []
var current_spawn_plan_index: int = 0
var current_plan_spawned: int = 0


func _ready() -> void:
	add_to_group("enemy_spawner")
	_resolve_battle_map()
	if bounty_enemy_pool == null:
		bounty_enemy_pool = DEFAULT_BOUNTY_ENEMY_POOL
	if battle_stats == null or battle_stats.get_wave_count() == 0:
		battle_finished = true
		call_deferred("_emit_battle_completed")
		return

	_start_wave(0)
	call_deferred("_try_spawn_random_bounty_elite")


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

	if current_wave_spawned >= current_wave_total_to_spawn:
		_mark_current_wave_spawn_finished()
		return

	_process_wave_spawn_plan(delta)


# 获取当前正在处理的波次数据。
func _get_current_wave_data() -> BattleWaveData:
	if battle_stats == null:
		return null
	return battle_stats.get_wave_data(current_wave_index)


# 启动指定波次，并重置这一波自己的计时状态。
func _start_wave(wave_index: int) -> void:
	current_wave_index = wave_index
	current_wave_spawned = 0
	current_wave_total_to_spawn = 0
	spawn_timer = 0.0
	next_wave_timer = 0.0
	waiting_for_next_wave = false
	current_wave_plan = _build_wave_spawn_plan(_get_current_wave_data())
	current_spawn_plan_index = 0
	current_plan_spawned = 0
	emit_signal("wave_started", current_wave_index)


# 把波次资源转换成运行时生成计划。
# fixed_spawns 会按填写顺序执行；旧的 packed_enemies 随机池会作为最后一个计划执行。
func _build_wave_spawn_plan(wave_data: BattleWaveData) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if wave_data == null:
		return plan

	current_wave_total_to_spawn = 0

	for entry in wave_data.fixed_spawns:
		if entry == null or not entry.is_valid_entry():
			continue
		current_wave_total_to_spawn += max(entry.count, 0)
		plan.append({
			"type": "fixed",
			"entry": entry,
			"count": entry.count,
			"spawn_interval": max(entry.spawn_interval, 0.0),
			"spawn_batch_size": max(entry.spawn_batch_size, 1),
		})

	if wave_data.has_random_pool():
		current_wave_total_to_spawn += max(wave_data.max_enemies, 0)
		plan.append({
			"type": "random",
			"wave_data": wave_data,
			"count": wave_data.max_enemies,
			"spawn_interval": max(wave_data.spawn_interval, 0.0),
			"spawn_batch_size": max(wave_data.spawn_batch_size, 1),
		})

	return plan


# 处理当前波次的生成计划。
# 间隔为 0 的计划会在同一帧生成完，适合 Boss 开场固定刷出。
func _process_wave_spawn_plan(delta: float) -> void:
	if current_wave_plan.is_empty():
		_mark_current_wave_spawn_finished()
		return

	spawn_timer += delta
	var safety := 0
	while current_spawn_plan_index < current_wave_plan.size() and safety < 1000:
		var plan := current_wave_plan[current_spawn_plan_index]
		var plan_count := int(plan.get("count", 0))
		if current_plan_spawned >= plan_count:
			_advance_spawn_plan()
			safety += 1
			continue

		var interval := float(plan.get("spawn_interval", 0.0))
		if interval > 0.0 and spawn_timer < interval:
			break

		if interval > 0.0:
			spawn_timer -= interval
		else:
			spawn_timer = 0.0

		_spawn_plan_batch(plan)
		if current_plan_spawned >= plan_count:
			_advance_spawn_plan()

		safety += 1

	if current_wave_spawned >= current_wave_total_to_spawn:
		_mark_current_wave_spawn_finished()


func _advance_spawn_plan() -> void:
	current_spawn_plan_index += 1
	current_plan_spawned = 0
	spawn_timer = 0.0


func _mark_current_wave_spawn_finished() -> void:
	if waiting_for_next_wave:
		return
	emit_signal("wave_spawn_finished", current_wave_index)
	_begin_wait_for_next_wave()


# 按当前计划生成一批敌人。
# 这里会记录“这一波已经生成了多少”和“当前场上活着多少只”。
func _spawn_plan_batch(plan: Dictionary) -> void:
	var batch_size := int(plan.get("spawn_batch_size", 1))
	var plan_count := int(plan.get("count", 0))
	for _spawn_index in range(max(batch_size, 1)):
		if current_plan_spawned >= plan_count:
			return

		var enemy := _spawn_enemy_from_plan(plan)
		current_plan_spawned += 1
		current_wave_spawned += 1

		if enemy == null:
			continue

		active_enemies.append(enemy)
		enemy.tree_exited.connect(_on_spawned_enemy_exited.bind(enemy), CONNECT_ONE_SHOT)


# 根据固定计划或随机计划实例化敌人。
func _spawn_enemy_from_plan(plan: Dictionary) -> Enemy:
	var spawn_entry := plan.get("entry") as EnemySpawnEntry
	var enemy_scene := _get_enemy_scene_from_plan(plan)
	if enemy_scene == null:
		return null

	var spawn_pos := _get_spawn_position(spawn_entry)
	return _spawn_enemy_scene(enemy_scene, spawn_pos)


func _get_enemy_scene_from_plan(plan: Dictionary) -> PackedScene:
	var plan_type := str(plan.get("type", ""))
	if plan_type == "fixed":
		var entry := plan.get("entry") as EnemySpawnEntry
		return entry.enemy_scene if entry != null else null

	var wave_data := plan.get("wave_data") as BattleWaveData
	if wave_data == null or wave_data.packed_enemies.is_empty():
		return null

	var enemy_scene: PackedScene = wave_data.packed_enemies.pick_random()
	return enemy_scene


# 实际实例化一只敌人，并登记到当前场景。
func _spawn_enemy_scene(enemy_scene: PackedScene, spawn_pos: Vector2) -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null

	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
	total_spawned += 1
	return enemy


func _get_spawn_position(entry: EnemySpawnEntry = null) -> Vector2:
	if entry == null:
		var fallback_position := _get_random_position_around(_get_spawn_around_position(), min_spawn_radius, max_spawn_radius)
		return _get_battle_map_enemy_spawn_position(min_spawn_radius, fallback_position)

	match entry.spawn_position_mode:
		EnemySpawnEntry.SpawnPositionMode.AROUND_SPAWNER:
			var fallback_position := _get_random_position_around(_get_spawner_position(), _resolve_min_radius(entry), _resolve_max_radius(entry))
			return _get_battle_map_enemy_spawn_position(_resolve_min_radius(entry), fallback_position)
		EnemySpawnEntry.SpawnPositionMode.FIXED_OFFSET:
			return _get_spawner_position() + entry.spawn_offset
		EnemySpawnEntry.SpawnPositionMode.MARKER_NODE:
			return _get_marker_position(entry) + entry.spawn_offset
		_:
			var fallback_position := _get_random_position_around(_get_spawn_around_position(), _resolve_min_radius(entry), _resolve_max_radius(entry))
			return _get_battle_map_enemy_spawn_position(_resolve_min_radius(entry), fallback_position)


# 优先从 BattleMap/SpawnPoints 里挑选敌人出生点；地图没有配置时保留旧的随机半径生成。
func _get_battle_map_enemy_spawn_position(min_distance: float, fallback_position: Vector2) -> Vector2:
	if battle_map == null:
		_resolve_battle_map()
	if battle_map == null:
		return fallback_position

	return battle_map.get_random_enemy_spawn_position(_get_spawn_around_position(), min_distance, fallback_position)


func _get_random_position_around(center: Vector2, min_radius: float, max_radius: float) -> Vector2:
	var safe_min = max(min_radius, 0.0)
	var safe_max = max(max_radius, safe_min)
	var spawn_radius := randf_range(safe_min, safe_max)
	var direction := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return center + direction.normalized() * spawn_radius


func _get_spawn_around_position() -> Vector2:
	if spawn_around != null:
		return spawn_around.global_position
	return _get_spawner_position()


func _get_spawner_position() -> Vector2:
	if get_parent() is Node2D:
		return (get_parent() as Node2D).global_position
	if spawn_around != null:
		return spawn_around.global_position
	return Vector2.ZERO


func _get_marker_position(entry: EnemySpawnEntry) -> Vector2:
	if entry == null or entry.marker_path == NodePath():
		return _get_spawner_position()

	var marker := get_node_or_null(entry.marker_path) as Node2D
	if marker == null and get_tree().current_scene != null:
		marker = get_tree().current_scene.get_node_or_null(entry.marker_path) as Node2D
	if marker == null:
		return _get_spawner_position()

	return marker.global_position


# EnemySpawner 的 _ready 可能先于 PlayScene 运行，所以这里自己兜底寻找地图引用。
func _resolve_battle_map() -> void:
	if battle_map != null:
		battle_map.refresh_layer_cache()
		return

	var parent := get_parent()
	if parent != null:
		battle_map = parent.get_node_or_null("BattleMap") as BattleMap
	if battle_map == null:
		battle_map = get_tree().get_first_node_in_group("battle_map") as BattleMap
	if battle_map != null:
		battle_map.refresh_layer_cache()


func _resolve_min_radius(entry: EnemySpawnEntry) -> float:
	if entry != null and entry.min_spawn_radius >= 0.0:
		return entry.min_spawn_radius
	return min_spawn_radius


func _resolve_max_radius(entry: EnemySpawnEntry) -> float:
	if entry != null and entry.max_spawn_radius >= 0.0:
		return entry.max_spawn_radius
	return max_spawn_radius


# 供 Boss 召唤、事件刷怪等非波次系统登记敌人。
# 登记后的敌人会进入 active_enemies，参与“场上敌人清空后才结束战斗”的判断。
func register_external_enemy(enemy: Enemy, count_for_victory: bool = true) -> void:
	if enemy == null or active_enemies.has(enemy) or active_bounty_enemies.has(enemy):
		return
	if not count_for_victory:
		_register_bounty_enemy(enemy)
		return

	active_enemies.append(enemy)
	enemy.tree_exited.connect(_on_spawned_enemy_exited.bind(enemy), CONNECT_ONE_SHOT)


## 从悬赏池中抽取并生成一只悬赏精英怪。
## 默认不加入 active_enemies，因此不会影响“清空普通敌人即可胜利”的判定。
func spawn_random_bounty_enemy(spawn_position: Vector2 = Vector2.ZERO, use_custom_position: bool = false) -> Enemy:
	var pool: BountyEnemyPool = _get_bounty_enemy_pool()
	if pool == null:
		return null

	var entry: BountyEnemyEntry = pool.get_random_entry()
	if entry == null:
		return null

	return spawn_bounty_enemy(entry, spawn_position, use_custom_position)


func spawn_bounty_enemy(entry: BountyEnemyEntry, spawn_position: Vector2 = Vector2.ZERO, use_custom_position: bool = false) -> Enemy:
	if entry == null or not entry.is_valid_entry():
		return null

	var final_position: Vector2 = spawn_position if use_custom_position else _get_spawn_position(null)
	var enemy: Enemy = _spawn_bounty_enemy_scene(entry.enemy_scene, final_position)
	if enemy == null:
		return null

	entry.apply_to_enemy(enemy)
	_register_bounty_enemy(enemy)
	return enemy


func _try_spawn_random_bounty_elite() -> void:
	if not enable_random_bounty_spawn:
		return
	if battle_stats == null or battle_finished:
		return
	if randf() > random_bounty_spawn_chance:
		return

	spawn_random_bounty_enemy()


func _get_bounty_enemy_pool() -> BountyEnemyPool:
	if bounty_enemy_pool == null:
		bounty_enemy_pool = DEFAULT_BOUNTY_ENEMY_POOL
	return bounty_enemy_pool


func _spawn_bounty_enemy_scene(enemy_scene: PackedScene, spawn_pos: Vector2) -> Enemy:
	if enemy_scene == null:
		return null

	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null

	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
	return enemy


func _register_bounty_enemy(enemy: Enemy) -> void:
	if enemy == null or active_bounty_enemies.has(enemy):
		return

	active_bounty_enemies.append(enemy)
	enemy.tree_exited.connect(_on_bounty_enemy_exited.bind(enemy), CONNECT_ONE_SHOT)
	bounty_enemy_presence_changed.emit(true)


func _on_bounty_enemy_exited(enemy: Enemy) -> void:
	active_bounty_enemies.erase(enemy)
	bounty_enemy_presence_changed.emit(has_active_bounty_enemies())


func has_active_bounty_enemies() -> bool:
	return not active_bounty_enemies.is_empty()


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
	if wave_data != null and current_wave_spawned >= current_wave_total_to_spawn and active_enemies.is_empty():
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

	if current_wave_spawned < current_wave_total_to_spawn:
		return

	if not active_enemies.is_empty():
		return

	battle_finished = true
	emit_signal("battle_completed")


# 给“空战斗”这种情况用的兜底触发。
func _emit_battle_completed() -> void:
	emit_signal("battle_completed")
