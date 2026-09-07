class_name BattleMapTerrainRandomizer
extends Node

## 模板战斗地图的“特殊地形随机化”控制器。
## 它读取 MapTerrainSpawnProfile，把火海、冰面、毒雾等特殊地形瓦片铺到 EffectLayer 上。

const DEFAULT_TERRAIN_SPAWN_PROFILE_PATH: String = "res://custom_resource/default_map_terrain_spawn_profile.tres"
const DEFAULT_MAP_TAG_INFLUENCE_DATABASE_PATH: String = "res://custom_resource/default_map_tag_influence_database.tres"

@export var enabled: bool = true
@export var battle_map_path: NodePath = NodePath("..")

@export_group("生成规则")
## 留空时读取 default_map_terrain_spawn_profile.tres。
@export var terrain_spawn_profile: MapTerrainSpawnProfile
## 标签影响数据库。玩家启用的地图标签会从这里读取特殊地形生成修正。
@export var map_tag_influence_database: MapTagInfluenceDatabase

@export_group("生成后处理")
## 如果特殊地形会影响 blocks_movement / move_cost，生成后重建寻路能让 AI 立刻读到变化。
@export var rebuild_navigation_after_randomize: bool = true

var battle_map: BattleMap
var run_stats: RunStats
var has_randomized: bool = false
var warned_missing_profile: bool = false
var warned_missing_map_tag_influence_database: bool = false


func _ready() -> void:
	if battle_map == null:
		battle_map = get_node_or_null(battle_map_path) as BattleMap


func bind_battle_map(new_battle_map: BattleMap) -> void:
	battle_map = new_battle_map


func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats


func randomize_terrain() -> int:
	if not enabled or has_randomized:
		return 0
	if battle_map == null:
		battle_map = get_node_or_null(battle_map_path) as BattleMap
	if battle_map == null:
		return 0

	battle_map.refresh_layer_cache()
	if battle_map.effect_layer == null:
		push_warning("BattleMapTerrainRandomizer 找不到 EffectLayer，无法随机生成特殊地形。")
		return 0

	var spawn_profile: MapTerrainSpawnProfile = _get_effective_terrain_spawn_profile()
	if spawn_profile == null or not spawn_profile.enabled:
		has_randomized = true
		return 0

	var terrain_areas: Array[BattleMapRandomArea] = battle_map.get_random_areas(BattleMapRandomArea.AreaType.TERRAIN)
	if terrain_areas.is_empty():
		has_randomized = true
		return 0

	var placed_count: int = 0
	for rule: MapTerrainSpawnRule in spawn_profile.get_enabled_rules():
		placed_count += _randomize_rule(rule, terrain_areas)

	has_randomized = true
	if placed_count > 0 and rebuild_navigation_after_randomize and battle_map.build_navigation_on_ready:
		battle_map.rebuild_navigation_grid()

	return placed_count


## 兼容旧调用名。后续外部如果还调用 randomize_fire_terrain，也会走新的资源化流程。
func randomize_fire_terrain() -> int:
	return randomize_terrain()


func _get_effective_terrain_spawn_profile() -> MapTerrainSpawnProfile:
	var profile: MapTerrainSpawnProfile = _get_terrain_spawn_profile()
	if profile == null:
		return null

	var effective_profile: MapTerrainSpawnProfile = profile.duplicate(true) as MapTerrainSpawnProfile
	if effective_profile == null:
		return profile

	_apply_enabled_map_tag_terrain_modifiers(effective_profile)
	return effective_profile


func _get_terrain_spawn_profile() -> MapTerrainSpawnProfile:
	if terrain_spawn_profile != null:
		return terrain_spawn_profile

	var loaded_resource: Resource = load(DEFAULT_TERRAIN_SPAWN_PROFILE_PATH)
	terrain_spawn_profile = loaded_resource as MapTerrainSpawnProfile
	if terrain_spawn_profile == null and not warned_missing_profile:
		warned_missing_profile = true
		push_warning("BattleMapTerrainRandomizer 无法读取默认 MapTerrainSpawnProfile：%s" % DEFAULT_TERRAIN_SPAWN_PROFILE_PATH)
	return terrain_spawn_profile


func _apply_enabled_map_tag_terrain_modifiers(spawn_profile: MapTerrainSpawnProfile) -> void:
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

		# 地图标签配置按“单个标签实例”启用：同一个 key 出现多次，就会多次修正规则。
		for modifier: MapTagTerrainSpawnModifier in influence.terrain_spawn_modifiers:
			_apply_terrain_modifier_to_profile(spawn_profile, modifier)


func _apply_terrain_modifier_to_profile(
	spawn_profile: MapTerrainSpawnProfile,
	modifier: MapTagTerrainSpawnModifier
) -> void:
	if spawn_profile == null or modifier == null:
		return

	for rule: MapTerrainSpawnRule in spawn_profile.rules:
		if rule == null:
			continue
		if modifier.terrain_id != &"" and modifier.terrain_id != rule.terrain_id:
			continue

		rule.chance = clamp((rule.chance * modifier.chance_multiplier) + modifier.chance_bonus, 0.0, 1.0)
		rule.min_count_per_area = max(_scale_count(rule.min_count_per_area, modifier.area_multiplier) + modifier.flat_count_bonus, 0)
		rule.max_count_per_area = max(_scale_count(rule.max_count_per_area, modifier.area_multiplier) + modifier.flat_count_bonus, rule.min_count_per_area)


func _scale_count(value: int, multiplier: float) -> int:
	if multiplier == 1.0:
		return value
	return int(round(float(value) * max(multiplier, 0.0)))


func _randomize_rule(rule: MapTerrainSpawnRule, terrain_areas: Array[BattleMapRandomArea]) -> int:
	if rule == null or not rule.is_valid_rule():
		return 0
	if not _has_rule_tile(rule):
		push_warning("BattleMapTerrainRandomizer 找不到特殊地形瓦片：terrain_id=%s, source_id=%s, atlas_coords=%s。" % [rule.terrain_id, rule.source_id, rule.atlas_coords])
		return 0

	var placed_count: int = 0
	for area: BattleMapRandomArea in terrain_areas:
		if not rule.can_spawn_in_area(area):
			continue
		placed_count += _randomize_rule_in_area(rule, area)

	return placed_count


func _randomize_rule_in_area(rule: MapTerrainSpawnRule, area: BattleMapRandomArea) -> int:
	var candidates: Array[Vector2i] = _collect_candidate_cells(rule, area)
	if candidates.is_empty():
		return 0

	var target_count: int = rule.roll_count(candidates.size())
	if target_count <= 0:
		return 0

	var placed_count: int = 0
	var attempts: int = min(max(rule.max_attempts_per_area, 1), candidates.size())
	for _attempt: int in range(attempts):
		if placed_count >= target_count or candidates.is_empty():
			break

		var index: int = RunRng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[index]
		candidates.remove_at(index)
		_place_rule_cell(rule, cell)
		placed_count += 1

	return placed_count


func _collect_candidate_cells(rule: MapTerrainSpawnRule, area: BattleMapRandomArea) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cells: Array[Vector2i] = area.get_cells_in_area(battle_map)
	for cell: Vector2i in cells:
		if not _can_place_rule_at_cell(rule, cell):
			continue
		result.append(cell)
	return result


func _can_place_rule_at_cell(rule: MapTerrainSpawnRule, cell: Vector2i) -> bool:
	if battle_map == null or battle_map.effect_layer == null:
		return false

	var world_position: Vector2 = battle_map.cell_to_world_center(cell)
	if rule.require_walkable and not battle_map.is_world_position_walkable(world_position):
		return false
	if not rule.overwrite_existing_effect_tiles and battle_map.effect_layer.get_cell_source_id(cell) != -1:
		return false

	return true


func _place_rule_cell(rule: MapTerrainSpawnRule, cell: Vector2i) -> void:
	battle_map.effect_layer.set_cell(
		cell,
		rule.source_id,
		rule.atlas_coords,
		rule.alternative_tile
	)


func _has_rule_tile(rule: MapTerrainSpawnRule) -> bool:
	if rule == null or battle_map == null or battle_map.effect_layer == null:
		return false

	var tile_set: TileSet = battle_map.effect_layer.tile_set
	if tile_set == null:
		return false
	if not tile_set.has_source(rule.source_id):
		return false

	var source: TileSetSource = tile_set.get_source(rule.source_id)
	var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
	if atlas_source == null:
		return true

	return atlas_source.has_tile(rule.atlas_coords)


func _get_map_tag_influence_database() -> MapTagInfluenceDatabase:
	if map_tag_influence_database != null:
		return map_tag_influence_database

	var loaded_resource: Resource = load(DEFAULT_MAP_TAG_INFLUENCE_DATABASE_PATH)
	map_tag_influence_database = loaded_resource as MapTagInfluenceDatabase
	if map_tag_influence_database == null and not warned_missing_map_tag_influence_database:
		warned_missing_map_tag_influence_database = true
		push_warning("BattleMapTerrainRandomizer 无法读取默认 MapTagInfluenceDatabase：%s" % DEFAULT_MAP_TAG_INFLUENCE_DATABASE_PATH)
	return map_tag_influence_database
