class_name ObjectSpawnerFromTileMap
extends Node2D

## 从专门的 TileMapLayer 读取 object_id，把编辑器里的“标记瓦片”转换成真实地图实体。
## 这样 ObjectSpawnLayer 只负责关卡标记，真正可交互的苹果树、矿石、陷阱等仍然走独立场景脚本。
const CUSTOM_OBJECT_ID: StringName = &"object_id"
const DEFAULT_MAP_OBJECT_DATABASE_PATH: String = "res://custom_resource/default_map_object_database.tres"
const DEFAULT_MAP_TAG_INFLUENCE_DATABASE_PATH: String = "res://custom_resource/default_map_tag_influence_database.tres"

@export_group("节点路径")
## 默认作为 BattleMap 的子节点使用，所以父节点就是 BattleMap。
@export var battle_map_path: NodePath = NodePath("..")
## 如果没有绑定 BattleMap，也可以直接用这个路径查找生成标记层。
@export var object_spawn_layer_path: NodePath = NodePath("../ObjectSpawnLayer")
## 生成出的地图实体会优先放到 ObjectContainer 下，方便统一清理。
@export var object_container_path: NodePath = NodePath("../ObjectContainer")

@export_group("生成配置")
## 正式的 object_id -> 场景映射。以后新增地图物件，优先在这个资源里配置。
@export var object_database: MapObjectDatabase
## 调试/临时覆盖用：可在检查器里填 object_id -> PackedScene 或 object_id -> 场景路径。
@export var object_scene_overrides: Dictionary = {}
## 有些素材的脚底点不在瓦片中心时，可以用这个偏移统一修正。
@export var spawn_offset: Vector2 = Vector2.ZERO

@export_group("随机生成")
## 开启后，会在手动 ObjectSpawnLayer 标记生成完成后，再按 Profile 自动补地图物件。
@export var enable_random_spawn: bool = true
@export var random_spawn_profile: MapObjectSpawnProfile
## 标签影响数据库。玩家启用的地图标签会从这里读取“地图特殊物体/特殊地形”的修正。
@export var map_tag_influence_database: MapTagInfluenceDatabase
## 开启后，模板地图中的 BattleMapRandomArea 会优先决定随机地图物体的大致出现区域。
@export var prefer_random_areas: bool = true
## 区域内找不到合法位置时，是否回退到整张地图随机，避免小区域配置过窄导致完全不生成。
@export var fallback_to_whole_map_when_area_failed: bool = true

@export_group("标记层生成")
## 生成后清空标记层，避免玩家看见用于刷物件的占位瓦片。
@export var clear_tiles_after_spawn: bool = true
## 开启后进入场景会自动生成；PlayScene 也会主动调用，内部有防重复保护。
@export var auto_spawn_on_ready: bool = true
## 默认防止重复生成。调试时如果想反复刷，可以临时打开。
@export var allow_duplicate_spawn: bool = false
@export var warn_unknown_object_id: bool = true

var battle_map: BattleMap
var object_spawn_layer: TileMapLayer
var object_container: Node
var spawned_objects: Array[Node] = []
var has_spawned: bool = false
var run_stats: RunStats
var warned_missing_object_id_layer: bool = false
var warned_missing_database: bool = false
var warned_missing_map_tag_influence_database: bool = false


func _ready() -> void:
	if auto_spawn_on_ready:
		call_deferred("spawn_objects")


## 外部可显式绑定 BattleMap，避免依赖节点路径；PlayScene 初始化时会走这个入口。
func bind_battle_map(new_battle_map: BattleMap) -> void:
	battle_map = new_battle_map
	_resolve_nodes()


## 绑定本局数据后，随机生成地图物件时才能读取玩家启用的地图标签。
func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	_bind_run_stats_to_spawned_objects()


## 扫描 ObjectSpawnLayer 上的每个格子，并按 object_id 实例化对应地图实体；随后按随机 Profile 自动补物件。
func spawn_objects() -> void:
	if has_spawned and not allow_duplicate_spawn:
		return

	_resolve_nodes()

	if allow_duplicate_spawn:
		clear_spawned_objects()

	_spawn_marked_objects()
	_spawn_random_profile_objects()
	has_spawned = true


func _spawn_marked_objects() -> int:
	if object_spawn_layer == null:
		return 0

	if not _tile_set_has_custom_data_layer(object_spawn_layer.tile_set, CUSTOM_OBJECT_ID):
		push_warning("ObjectSpawnLayer 的 TileSet 缺少 custom data 层：object_id，标记层地图物件不会生成。")
		return 0

	var spawn_count: int = 0
	for cell_value in object_spawn_layer.get_used_cells():
		var cell: Vector2i = cell_value
		var object_id: StringName = _get_object_id_at_cell(cell)
		if object_id == &"":
			continue

		var spawned_object: Node = spawn_object_at_cell(object_id, cell)
		if spawned_object != null:
			spawned_objects.append(spawned_object)
			spawn_count += 1

	if clear_tiles_after_spawn and spawn_count > 0:
		object_spawn_layer.clear()

	return spawn_count


func _spawn_random_profile_objects() -> int:
	if not enable_random_spawn:
		return 0
	var spawn_profile: MapObjectSpawnProfile = _get_effective_random_spawn_profile()
	if spawn_profile == null or not spawn_profile.enabled:
		return 0
	if battle_map == null:
		return 0

	var spawn_count: int = 0
	var occupied_positions: Array[Vector2] = _collect_existing_object_positions()

	for rule: MapObjectSpawnRule in spawn_profile.get_enabled_rules():
		var rule_count: int = rule.roll_count()
		spawn_count += _spawn_rule_objects(rule, rule_count, occupied_positions)

	var bonus_count: int = spawn_profile.roll_bonus_count()
	for _index: int in range(bonus_count):
		var bonus_rule: MapObjectSpawnRule = spawn_profile.pick_weighted_rule()
		if bonus_rule == null:
			continue
		spawn_count += _spawn_rule_objects(bonus_rule, 1, occupied_positions)

	return spawn_count


## 单独生成一个 object_id 对应的实体，之后事件房间或随机地图也可以复用这个入口。
func spawn_object_at_cell(object_id: StringName, cell: Vector2i) -> Node:
	return spawn_object_at_position(object_id, _get_cell_world_position(cell))


## 在指定世界坐标生成一个 object_id 对应的实体。随机生成和事件生成都可以复用它。
func spawn_object_at_position(object_id: StringName, world_position: Vector2, extra_spawn_offset: Vector2 = Vector2.ZERO) -> Node:
	var object_entry: MapObjectEntry = _get_entry_for_object_id(object_id)
	var object_scene: PackedScene = _get_scene_for_object_id(object_id, object_entry)
	if object_scene == null:
		if warn_unknown_object_id:
			push_warning("ObjectSpawnerFromTileMap 找不到 object_id 对应场景：%s。请检查 MapObjectDatabase。" % String(object_id))
		return null

	var instance: Node = object_scene.instantiate()
	if instance == null:
		return null

	var target_container: Node = _get_target_container()
	target_container.add_child(instance)

	_bind_run_stats_to_object(instance)

	if instance is Node2D:
		var object_node: Node2D = instance as Node2D
		object_node.global_position = world_position + spawn_offset + _get_entry_spawn_offset(object_entry) + extra_spawn_offset

	if EventBus != null:
		EventBus.map_object_spawned.emit(instance)

	return instance


## 清理由本生成器生成的物件，主要给调试或运行时换地图使用。
func clear_spawned_objects() -> void:
	for object_node: Node in spawned_objects:
		if object_node == null or not is_instance_valid(object_node):
			continue
		object_node.queue_free()

	spawned_objects.clear()
	has_spawned = false


func _resolve_nodes() -> void:
	if battle_map == null:
		battle_map = get_node_or_null(battle_map_path) as BattleMap
	if battle_map != null:
		battle_map.refresh_layer_cache()
		object_spawn_layer = battle_map.get_object_spawn_layer()
		object_container = battle_map.get_object_container()

	if object_spawn_layer == null:
		object_spawn_layer = get_node_or_null(object_spawn_layer_path) as TileMapLayer
	if object_container == null:
		object_container = get_node_or_null(object_container_path)


func _get_effective_random_spawn_profile() -> MapObjectSpawnProfile:
	if random_spawn_profile == null:
		return null

	var effective_profile: MapObjectSpawnProfile = random_spawn_profile.duplicate(true) as MapObjectSpawnProfile
	if effective_profile == null:
		return random_spawn_profile

	_apply_enabled_map_tag_object_modifiers(effective_profile)
	return effective_profile


func _apply_enabled_map_tag_object_modifiers(spawn_profile: MapObjectSpawnProfile) -> void:
	if spawn_profile == null or run_stats == null:
		return

	var enabled_tag_keys: Array[String] = run_stats.get_enabled_map_tag_keys()
	if enabled_tag_keys.is_empty():
		return

	var influence_database: MapTagInfluenceDatabase = _get_map_tag_influence_database()
	if influence_database == null:
		return

	for tag_key: String in enabled_tag_keys:
		var influence: MapTagInfluenceData = influence_database.get_influence_for_tag_key(tag_key)
		if influence == null or not influence.enabled:
			continue

		# 地图标签配置现在按“单个标签实例”启用：数组里每出现一次 key，就只结算 1 份该标签效果。
		var tag_count: int = 1
		for modifier: MapTagObjectSpawnModifier in influence.object_spawn_modifiers:
			_apply_object_modifier_to_profile(spawn_profile, modifier, tag_count)


func _apply_object_modifier_to_profile(
	spawn_profile: MapObjectSpawnProfile,
	modifier: MapTagObjectSpawnModifier,
	tag_count: int
) -> void:
	if spawn_profile == null or modifier == null:
		return

	for rule: MapObjectSpawnRule in spawn_profile.rules:
		if rule == null:
			continue

		var object_entry: MapObjectEntry = _get_entry_for_object_id(rule.object_id)
		if not modifier.matches_object(rule.object_id, object_entry):
			continue

		rule.chance = clamp(rule.chance + modifier.chance_bonus, 0.0, 1.0)
		rule.min_count = max(rule.min_count + modifier.get_min_count_bonus(tag_count), 0)
		rule.max_count = max(rule.max_count + modifier.get_max_count_bonus(tag_count), rule.min_count)
		rule.weight = max(rule.weight + modifier.get_weight_bonus(tag_count), 0.0)


func _spawn_rule_objects(rule: MapObjectSpawnRule, count: int, occupied_positions: Array[Vector2]) -> int:
	if rule == null or count <= 0:
		return 0

	var spawn_count: int = 0
	for _index: int in range(count):
		var spawn_object_id: StringName = _pick_spawn_object_id(rule)
		if spawn_object_id == &"":
			continue
		var spawn_position_value: Variant = _pick_random_position_for_rule(rule, occupied_positions)
		if not (spawn_position_value is Vector2):
			push_warning("ObjectSpawnerFromTileMap 无法为随机物件找到可用位置：%s" % String(rule.object_id))
			continue

		var spawn_position: Vector2 = spawn_position_value
		var spawned_object: Node = spawn_object_at_position(spawn_object_id, spawn_position, rule.spawn_offset)
		if spawned_object == null:
			continue

		spawned_objects.append(spawned_object)
		occupied_positions.append(spawn_position)
		spawn_count += 1

	return spawn_count


## 规则可以直接生成一个物体，也可以先从变体池中抽取具体物体。
func _pick_spawn_object_id(rule: MapObjectSpawnRule) -> StringName:
	if rule == null:
		return &""
	if rule.variant_pool == null:
		return rule.object_id

	var weight_bonuses: Dictionary = {}
	if run_stats != null:
		weight_bonuses = run_stats.get_map_object_spawn_weight_bonuses()
	return rule.variant_pool.pick_weighted_object_id(weight_bonuses)


func _pick_random_position_for_rule(rule: MapObjectSpawnRule, occupied_positions: Array[Vector2]) -> Variant:
	if battle_map == null:
		return null

	var player_spawn_positions: Array[Vector2] = _get_player_spawn_positions()
	var enemy_spawn_positions: Array[Vector2] = _get_enemy_spawn_positions()
	var attempts: int = max(rule.max_attempts_per_object, 1)

	if prefer_random_areas and battle_map.has_map_object_random_areas(rule.object_id):
		var area_position_value: Variant = _pick_random_area_position_for_rule(
			rule,
			occupied_positions,
			player_spawn_positions,
			enemy_spawn_positions,
			attempts
		)
		if area_position_value is Vector2:
			return area_position_value
		if not fallback_to_whole_map_when_area_failed:
			return null

	for _attempt: int in range(attempts):
		var position_value: Variant = battle_map.get_random_walkable_position()
		if not (position_value is Vector2):
			return null

		var candidate_position: Vector2 = position_value
		if _is_spawn_position_valid_for_rule(rule, candidate_position, occupied_positions, player_spawn_positions, enemy_spawn_positions):
			return candidate_position

	return null


func _pick_random_area_position_for_rule(
	rule: MapObjectSpawnRule,
	occupied_positions: Array[Vector2],
	player_spawn_positions: Array[Vector2],
	enemy_spawn_positions: Array[Vector2],
	attempts: int
) -> Variant:
	for _attempt: int in range(attempts):
		var position_value: Variant = battle_map.get_random_map_object_spawn_position(rule.object_id, attempts)
		if not (position_value is Vector2):
			continue

		var candidate_position: Vector2 = position_value
		if _is_spawn_position_valid_for_rule(rule, candidate_position, occupied_positions, player_spawn_positions, enemy_spawn_positions):
			return candidate_position

	return null


func _is_spawn_position_valid_for_rule(
	rule: MapObjectSpawnRule,
	candidate_position: Vector2,
	occupied_positions: Array[Vector2],
	player_spawn_positions: Array[Vector2],
	enemy_spawn_positions: Array[Vector2]
) -> bool:
	if rule.require_walkable and not battle_map.is_world_position_walkable(candidate_position):
		return false
	if rule.avoid_player_spawn and _is_too_close_to_positions(candidate_position, player_spawn_positions, rule.min_distance_from_player_spawn):
		return false
	if rule.avoid_enemy_spawns and _is_too_close_to_positions(candidate_position, enemy_spawn_positions, rule.min_distance_from_enemy_spawns):
		return false
	if _is_too_close_to_positions(candidate_position, occupied_positions, rule.min_distance_from_other_objects):
		return false

	return true


func _collect_existing_object_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var seen_ids: Dictionary = {}

	for object_node: Node in spawned_objects:
		_append_object_position(object_node, result, seen_ids)

	if object_container != null:
		for child: Node in object_container.get_children():
			_append_object_position(child, result, seen_ids)

	return result


func _append_object_position(object_node: Node, result: Array[Vector2], seen_ids: Dictionary) -> void:
	if object_node == null or not is_instance_valid(object_node):
		return

	var object_id: int = object_node.get_instance_id()
	if seen_ids.has(object_id):
		return
	seen_ids[object_id] = true

	if object_node is Node2D:
		result.append((object_node as Node2D).global_position)


func _bind_run_stats_to_spawned_objects() -> void:
	var seen_ids: Dictionary = {}
	for object_node: Node in spawned_objects:
		_bind_run_stats_to_object_once(object_node, seen_ids)

	if object_container == null:
		return

	for child: Node in object_container.get_children():
		_bind_run_stats_to_object_once(child, seen_ids)


func _bind_run_stats_to_object_once(object_node: Node, seen_ids: Dictionary) -> void:
	if object_node == null or not is_instance_valid(object_node):
		return

	var object_id: int = object_node.get_instance_id()
	if seen_ids.has(object_id):
		return

	seen_ids[object_id] = true
	_bind_run_stats_to_object(object_node)


func _bind_run_stats_to_object(object_node: Node) -> void:
	if object_node == null or not is_instance_valid(object_node):
		return

	if object_node.has_method("bind_run_stats"):
		# 地图物件如果需要读取本局数据（背包、商店、角色构筑等），统一从生成器这里接入。
		object_node.call("bind_run_stats", run_stats)
	elif object_node.has_method("prepare_rewards"):
		# 兜底：少数物件可能只需要提前准备奖励，不需要持有整份 RunStats。
		object_node.call("prepare_rewards")


func _get_player_spawn_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if battle_map == null:
		return result

	result.append_array(battle_map.get_spawn_positions(BattleMap.SPAWN_PLAYER))
	if result.is_empty():
		result.append(battle_map.get_player_spawn_position())

	return result


func _get_enemy_spawn_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if battle_map == null:
		return result

	result.append_array(battle_map.get_spawn_positions(BattleMap.SPAWN_ENEMY))
	result.append_array(battle_map.get_spawn_positions(BattleMap.SPAWN_ANY))
	return result


func _is_too_close_to_positions(position: Vector2, reference_positions: Array[Vector2], min_distance: float) -> bool:
	if min_distance <= 0.0:
		return false

	for reference_position: Vector2 in reference_positions:
		if position.distance_to(reference_position) < min_distance:
			return true

	return false


func _get_object_id_at_cell(cell: Vector2i) -> StringName:
	var tile_data: TileData = object_spawn_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return &""
	if not _tile_set_has_custom_data_layer(object_spawn_layer.tile_set, CUSTOM_OBJECT_ID):
		if not warned_missing_object_id_layer:
			warned_missing_object_id_layer = true
			push_warning("ObjectSpawnLayer 的 TileSet 缺少 custom data 层：object_id。")
		return &""

	var value: Variant = tile_data.get_custom_data(CUSTOM_OBJECT_ID)
	if value == null:
		return &""

	var object_id_text: String = str(value).strip_edges()
	if object_id_text.is_empty():
		return &""

	return StringName(object_id_text)


func _get_entry_for_object_id(object_id: StringName) -> MapObjectEntry:
	var database: MapObjectDatabase = _get_object_database()
	if database == null:
		return null
	return database.get_entry(object_id)


func _get_scene_for_object_id(object_id: StringName, object_entry: MapObjectEntry) -> PackedScene:
	var object_id_text: String = String(object_id)
	var configured_scene: Variant = object_scene_overrides.get(object_id_text)
	if configured_scene == null:
		configured_scene = object_scene_overrides.get(object_id)

	if configured_scene is PackedScene:
		return configured_scene as PackedScene
	if configured_scene is String and not String(configured_scene).is_empty():
		return load(String(configured_scene)) as PackedScene

	if object_entry != null:
		return object_entry.scene

	return null


func _get_object_database() -> MapObjectDatabase:
	if object_database != null:
		return object_database

	var loaded_resource: Resource = load(DEFAULT_MAP_OBJECT_DATABASE_PATH)
	object_database = loaded_resource as MapObjectDatabase
	if object_database == null and not warned_missing_database:
		warned_missing_database = true
		push_warning("ObjectSpawnerFromTileMap 无法读取默认 MapObjectDatabase：%s" % DEFAULT_MAP_OBJECT_DATABASE_PATH)
	return object_database


func _get_map_tag_influence_database() -> MapTagInfluenceDatabase:
	if map_tag_influence_database != null:
		return map_tag_influence_database

	var loaded_resource: Resource = load(DEFAULT_MAP_TAG_INFLUENCE_DATABASE_PATH)
	map_tag_influence_database = loaded_resource as MapTagInfluenceDatabase
	if map_tag_influence_database == null and not warned_missing_map_tag_influence_database:
		warned_missing_map_tag_influence_database = true
		push_warning("ObjectSpawnerFromTileMap 无法读取默认 MapTagInfluenceDatabase：%s" % DEFAULT_MAP_TAG_INFLUENCE_DATABASE_PATH)
	return map_tag_influence_database


func _get_entry_spawn_offset(object_entry: MapObjectEntry) -> Vector2:
	if object_entry == null:
		return Vector2.ZERO
	return object_entry.spawn_offset


func _get_cell_world_position(cell: Vector2i) -> Vector2:
	if battle_map != null:
		return battle_map.cell_to_world_center(cell)
	if object_spawn_layer != null:
		return object_spawn_layer.to_global(object_spawn_layer.map_to_local(cell))
	return global_position


func _get_target_container() -> Node:
	if object_container != null:
		return object_container
	if battle_map != null:
		return battle_map
	return self


func _tile_set_has_custom_data_layer(tile_set: TileSet, layer_name: StringName) -> bool:
	if tile_set == null:
		return false

	return tile_set.get_custom_data_layer_by_name(String(layer_name)) >= 0
