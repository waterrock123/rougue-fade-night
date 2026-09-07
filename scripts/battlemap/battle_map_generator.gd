class_name BattleMapGenerator
extends Node

## 战斗地图随机生成器。
## 当前版本先做“草原主题最小闭环”：草地作为可走区域，道路作为视觉引导，山丘/墙作为边界和内部障碍。
signal map_generated

@export_group("节点路径")
## 默认作为 BattleMap 的子节点使用。
@export var battle_map_path: NodePath = NodePath("..")
@export var ground_layer_name: StringName = &"GroundLayer"
@export var road_layer_name: StringName = &"RoadLayer"
@export var obstacle_layer_name: StringName = &"ObstacleLayer"
@export var decoration_layer_name: StringName = &"DecorationLayer"
@export var effect_layer_name: StringName = &"EffectLayer"
@export var object_spawn_layer_name: StringName = &"ObjectSpawnLayer"
@export var spawn_points_name: StringName = &"SpawnPoints"

@export_group("Terrain 名称")
## 会按名字在对应 TileSet 里查找 Terrain，大小写不敏感。找不到时使用下面的 fallback id。
@export var grass_terrain_name: String = "grass"
@export var road_terrain_name: String = "road"
@export var hill_terrain_name: String = "hill"
@export var fallback_terrain_set: int = 0
@export var fallback_grass_terrain: int = 0
@export var fallback_road_terrain: int = 0
@export var fallback_hill_terrain: int = 0

@export_group("生成开关")
@export var auto_generate_on_ready: bool = true
@export var randomize_on_ready: bool = true
@export var random_seed: int = 0
## 随机地图会重写这些层，避免手工测试地图残留到新地图里。
@export var clear_decoration_layer: bool = true
@export var clear_effect_layer: bool = true
@export var clear_object_spawn_layer: bool = true

@export_group("地图尺寸")
@export_range(16, 160, 1) var map_width: int = 72
@export_range(12, 120, 1) var map_height: int = 42
## 开启后让地图格子围绕原点展开，方便玩家和相机仍在场景中心附近。
@export var center_map_on_origin: bool = true
@export var map_origin_override: Vector2i = Vector2i(-36, -21)
@export_range(0, 12, 1) var edge_noise_cells: int = 3
@export_range(1, 8, 1) var border_thickness_cells: int = 2
## 只影响草地绘制，不改变真实可走区域。草地多铺一圈可以更好衔接山丘边缘 tile。
@export_range(0, 4, 1) var ground_padding_cells: int = 1

@export_group("道路")
@export var create_roads: bool = true
@export_range(1, 5, 1) var road_radius_cells: int = 1
@export_range(0, 12, 1) var road_wander_cells: int = 4

@export_group("内部山丘/障碍")
@export_range(0, 30, 1) var hill_cluster_count: int = 8
@export_range(1, 8, 1) var hill_cluster_min_radius: int = 2
@export_range(1, 10, 1) var hill_cluster_max_radius: int = 5
@export_range(0.0, 1.0, 0.01) var hill_cluster_fill_chance: float = 0.74
@export_range(0, 16, 1) var protected_spawn_radius_cells: int = 5
@export_range(0, 4, 1) var protected_road_radius_cells: int = 1
@export_range(1, 400, 1) var max_hill_cluster_attempts: int = 120

var battle_map: BattleMap
var ground_layer: TileMapLayer
var road_layer: TileMapLayer
var obstacle_layer: TileMapLayer
var decoration_layer: TileMapLayer
var effect_layer: TileMapLayer
var object_spawn_layer: TileMapLayer
var spawn_points_node: Node
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if auto_generate_on_ready:
		generate_random_map()


## 重新生成整张战斗地图，并在结束后刷新 BattleMap 的寻路与缓存。
func generate_random_map() -> void:
	_resolve_nodes()
	if not _has_required_layers():
		return

	_prepare_rng()

	var layout: Dictionary = _build_layout()
	_paint_layout(layout)
	_position_spawn_markers(layout)
	_refresh_battle_map()
	map_generated.emit()


func _resolve_nodes() -> void:
	battle_map = get_node_or_null(battle_map_path) as BattleMap
	if battle_map == null:
		return

	battle_map.refresh_layer_cache()
	ground_layer = battle_map.get_node_or_null(NodePath(String(ground_layer_name))) as TileMapLayer
	road_layer = battle_map.get_node_or_null(NodePath(String(road_layer_name))) as TileMapLayer
	obstacle_layer = battle_map.get_node_or_null(NodePath(String(obstacle_layer_name))) as TileMapLayer
	decoration_layer = battle_map.get_node_or_null(NodePath(String(decoration_layer_name))) as TileMapLayer
	effect_layer = battle_map.get_node_or_null(NodePath(String(effect_layer_name))) as TileMapLayer
	object_spawn_layer = battle_map.get_node_or_null(NodePath(String(object_spawn_layer_name))) as TileMapLayer
	spawn_points_node = battle_map.get_node_or_null(NodePath(String(spawn_points_name)))


func _has_required_layers() -> bool:
	if battle_map == null:
		push_warning("BattleMapGenerator 找不到 BattleMap，无法生成随机地图。")
		return false
	if ground_layer == null:
		push_warning("BattleMapGenerator 找不到 GroundLayer，无法生成草地。")
		return false
	if road_layer == null:
		push_warning("BattleMapGenerator 找不到 RoadLayer，无法生成道路。")
		return false
	if obstacle_layer == null:
		push_warning("BattleMapGenerator 找不到 ObstacleLayer，无法生成山丘边界。")
		return false
	return true


func _prepare_rng() -> void:
	if randomize_on_ready:
		rng.randomize()
		return

	rng.seed = random_seed


func _build_layout() -> Dictionary:
	var walkable_cells: Dictionary = _build_arena_walkable_cells()
	var player_spawn_cell: Vector2i = _find_nearest_walkable_cell(_get_player_spawn_target_cell(), walkable_cells)
	var enemy_spawn_cells: Array[Vector2i] = _build_enemy_spawn_cells(walkable_cells)
	var road_cells: Dictionary = _build_road_cells(walkable_cells, player_spawn_cell, enemy_spawn_cells)
	var protected_cells: Dictionary = _build_protected_cells(player_spawn_cell, enemy_spawn_cells, road_cells)
	var inner_hill_cells: Dictionary = _build_inner_hill_cells(walkable_cells, protected_cells)
	var outside_hill_cells: Dictionary = _build_outside_hill_cells(walkable_cells)
	var all_hill_cells: Dictionary = outside_hill_cells.duplicate()

	for cell_value in inner_hill_cells.keys():
		all_hill_cells[cell_value] = true

	for cell_value in all_hill_cells.keys():
		road_cells.erase(cell_value)

	return {
		"walkable_cells": walkable_cells,
		"road_cells": road_cells,
		"hill_cells": all_hill_cells,
		"player_spawn_cell": player_spawn_cell,
		"enemy_spawn_cells": enemy_spawn_cells,
	}


func _build_arena_walkable_cells() -> Dictionary:
	var result: Dictionary = {}
	var origin: Vector2i = _get_map_origin()
	var center_x: float = float(origin.x) + (float(map_width) - 1.0) * 0.5
	var center_y: float = float(origin.y) + (float(map_height) - 1.0) * 0.5
	var radius_y: float = max((float(map_height) - float(border_thickness_cells * 2)) * 0.5, 1.0)
	var base_radius_x: float = max((float(map_width) - float(border_thickness_cells * 2)) * 0.5, 1.0)

	for local_y: int in range(map_height):
		var cell_y: int = origin.y + local_y
		var normalized_y: float = (float(cell_y) - center_y) / radius_y
		var row_factor: float = sqrt(max(1.0 - normalized_y * normalized_y, 0.0))
		var row_noise: int = rng.randi_range(-edge_noise_cells, edge_noise_cells)
		var half_width: int = max(int(round(base_radius_x * row_factor)) + row_noise, 2)

		for local_x: int in range(map_width):
			var cell_x: int = origin.x + local_x
			if _is_on_rect_border(local_x, local_y):
				continue
			if abs(cell_x - center_x) <= float(half_width):
				result[Vector2i(cell_x, cell_y)] = true

	return result


func _is_on_rect_border(local_x: int, local_y: int) -> bool:
	if local_x < border_thickness_cells:
		return true
	if local_y < border_thickness_cells:
		return true
	if local_x >= map_width - border_thickness_cells:
		return true
	if local_y >= map_height - border_thickness_cells:
		return true
	return false


func _build_enemy_spawn_cells(walkable_cells: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin: Vector2i = _get_map_origin()
	var target_x: int = origin.x + int(round(float(map_width) * 0.78))
	var target_rows: Array[float] = [0.22, 0.42, 0.60, 0.78]

	for row_factor: float in target_rows:
		var target_y: int = origin.y + int(round(float(map_height) * row_factor))
		var spawn_cell: Vector2i = _find_nearest_walkable_cell(Vector2i(target_x, target_y), walkable_cells)
		if not result.has(spawn_cell):
			result.append(spawn_cell)

	return result


func _build_road_cells(
	walkable_cells: Dictionary,
	player_spawn_cell: Vector2i,
	enemy_spawn_cells: Array[Vector2i]
) -> Dictionary:
	var result: Dictionary = {}
	if not create_roads:
		return result

	for enemy_cell: Vector2i in enemy_spawn_cells:
		_add_wandering_road(result, walkable_cells, player_spawn_cell, enemy_cell)

	return result


func _add_wandering_road(
	road_cells: Dictionary,
	walkable_cells: Dictionary,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> void:
	var midpoint_x: int = int(round(lerp(float(start_cell.x), float(end_cell.x), 0.5)))
	var midpoint_y: int = int(round(lerp(float(start_cell.y), float(end_cell.y), 0.5))) + rng.randi_range(-road_wander_cells, road_wander_cells)
	var midpoint: Vector2i = _find_nearest_walkable_cell(Vector2i(midpoint_x, midpoint_y), walkable_cells)

	_add_road_line(road_cells, walkable_cells, start_cell, midpoint)
	_add_road_line(road_cells, walkable_cells, midpoint, end_cell)


func _add_road_line(
	road_cells: Dictionary,
	walkable_cells: Dictionary,
	start_cell: Vector2i,
	end_cell: Vector2i
) -> void:
	var delta: Vector2i = end_cell - start_cell
	var steps: int = max(abs(delta.x), abs(delta.y))
	if steps <= 0:
		_add_disk_cells(road_cells, walkable_cells, start_cell, road_radius_cells)
		return

	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		var road_cell: Vector2i = Vector2i(
			int(round(lerp(float(start_cell.x), float(end_cell.x), t))),
			int(round(lerp(float(start_cell.y), float(end_cell.y), t)))
		)
		_add_disk_cells(road_cells, walkable_cells, road_cell, road_radius_cells)


func _add_disk_cells(target_cells: Dictionary, allowed_cells: Dictionary, center_cell: Vector2i, radius: int) -> void:
	var safe_radius: int = max(radius, 0)
	for y_offset: int in range(-safe_radius, safe_radius + 1):
		for x_offset: int in range(-safe_radius, safe_radius + 1):
			var offset: Vector2i = Vector2i(x_offset, y_offset)
			if offset.length() > float(safe_radius) + 0.25:
				continue
			var cell: Vector2i = center_cell + offset
			if allowed_cells.has(cell):
				target_cells[cell] = true


func _build_protected_cells(
	player_spawn_cell: Vector2i,
	enemy_spawn_cells: Array[Vector2i],
	road_cells: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	var spawn_cells: Array[Vector2i] = [player_spawn_cell]
	spawn_cells.append_array(enemy_spawn_cells)

	for spawn_cell: Vector2i in spawn_cells:
		_add_square_cells(result, spawn_cell, protected_spawn_radius_cells)

	for road_cell_value in road_cells.keys():
		var road_cell: Vector2i = road_cell_value
		_add_square_cells(result, road_cell, protected_road_radius_cells)

	return result


func _add_square_cells(target_cells: Dictionary, center_cell: Vector2i, radius: int) -> void:
	var safe_radius: int = max(radius, 0)
	for y_offset: int in range(-safe_radius, safe_radius + 1):
		for x_offset: int in range(-safe_radius, safe_radius + 1):
			target_cells[center_cell + Vector2i(x_offset, y_offset)] = true


func _build_inner_hill_cells(walkable_cells: Dictionary, protected_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var accepted_count: int = 0
	var attempts: int = 0

	while accepted_count < hill_cluster_count and attempts < max_hill_cluster_attempts:
		attempts += 1
		var center_cell: Vector2i = _pick_random_walkable_cell(walkable_cells)
		if protected_cells.has(center_cell):
			continue

		var cluster_cells: Dictionary = _build_hill_cluster(center_cell, walkable_cells, protected_cells)
		if cluster_cells.is_empty():
			continue

		var proposed_cells: Dictionary = result.duplicate()
		for cell_value in cluster_cells.keys():
			proposed_cells[cell_value] = true

		if not _is_walkable_area_connected(walkable_cells, proposed_cells):
			continue

		result = proposed_cells
		accepted_count += 1

	return result


func _build_hill_cluster(center_cell: Vector2i, walkable_cells: Dictionary, protected_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var radius: int = rng.randi_range(hill_cluster_min_radius, max(hill_cluster_min_radius, hill_cluster_max_radius))

	for y_offset: int in range(-radius, radius + 1):
		for x_offset: int in range(-radius, radius + 1):
			var offset: Vector2i = Vector2i(x_offset, y_offset)
			var distance_ratio: float = offset.length() / float(max(radius, 1))
			if distance_ratio > 1.0:
				continue
			if rng.randf() > hill_cluster_fill_chance * (1.1 - distance_ratio * 0.45):
				continue

			var cell: Vector2i = center_cell + offset
			if not walkable_cells.has(cell):
				continue
			if protected_cells.has(cell):
				continue
			result[cell] = true

	return result


func _build_outside_hill_cells(walkable_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var origin: Vector2i = _get_map_origin()

	for local_y: int in range(map_height):
		for local_x: int in range(map_width):
			var cell: Vector2i = origin + Vector2i(local_x, local_y)
			if not walkable_cells.has(cell):
				result[cell] = true

	return result


func _is_walkable_area_connected(walkable_cells: Dictionary, blocked_cells: Dictionary) -> bool:
	var start_cell_value: Variant = null
	for cell_value in walkable_cells.keys():
		if blocked_cells.has(cell_value):
			continue
		start_cell_value = cell_value
		break

	if start_cell_value == null:
		return false

	var start_cell: Vector2i = start_cell_value
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_cell]
	visited[start_cell] = true

	while not queue.is_empty():
		var current_cell: Vector2i = queue.pop_front()
		for direction: Vector2i in _get_cardinal_directions():
			var next_cell: Vector2i = current_cell + direction
			if visited.has(next_cell):
				continue
			if not walkable_cells.has(next_cell):
				continue
			if blocked_cells.has(next_cell):
				continue
			visited[next_cell] = true
			queue.append(next_cell)

	for cell_value in walkable_cells.keys():
		if blocked_cells.has(cell_value):
			continue
		if not visited.has(cell_value):
			return false

	return true


func _paint_layout(layout: Dictionary) -> void:
	_clear_target_layers()

	var walkable_cells: Dictionary = layout.get("walkable_cells", {})
	var road_cells: Dictionary = layout.get("road_cells", {})
	var hill_cells: Dictionary = layout.get("hill_cells", {})
	var painted_ground_cells: Dictionary = _expand_cells_inside_generation_rect(walkable_cells, ground_padding_cells)

	_paint_terrain_cells(ground_layer, painted_ground_cells, grass_terrain_name, fallback_terrain_set, fallback_grass_terrain)
	_paint_terrain_cells(road_layer, road_cells, road_terrain_name, fallback_terrain_set, fallback_road_terrain)
	_paint_terrain_cells(obstacle_layer, hill_cells, hill_terrain_name, fallback_terrain_set, fallback_hill_terrain)


func _clear_target_layers() -> void:
	ground_layer.clear()
	road_layer.clear()
	obstacle_layer.clear()

	if clear_decoration_layer and decoration_layer != null:
		decoration_layer.clear()
	if clear_effect_layer and effect_layer != null:
		effect_layer.clear()
	if clear_object_spawn_layer and object_spawn_layer != null:
		object_spawn_layer.clear()


func _paint_terrain_cells(
	layer: TileMapLayer,
	cells_dict: Dictionary,
	terrain_name: String,
	fallback_set: int,
	fallback_terrain: int
) -> void:
	if layer == null or cells_dict.is_empty():
		return

	var cells: Array[Vector2i] = _dictionary_keys_to_cells(cells_dict)
	var terrain_info: Vector2i = _resolve_terrain_info(layer.tile_set, terrain_name, fallback_set, fallback_terrain)
	layer.set_cells_terrain_connect(cells, terrain_info.x, terrain_info.y, true)


func _dictionary_keys_to_cells(cells_dict: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_value in cells_dict.keys():
		var cell: Vector2i = cell_value
		result.append(cell)
	return result


func _expand_cells_inside_generation_rect(source_cells: Dictionary, padding: int) -> Dictionary:
	var result: Dictionary = source_cells.duplicate()
	var safe_padding: int = max(padding, 0)
	if safe_padding <= 0:
		return result

	for cell_value in source_cells.keys():
		var source_cell: Vector2i = cell_value
		for y_offset: int in range(-safe_padding, safe_padding + 1):
			for x_offset: int in range(-safe_padding, safe_padding + 1):
				var padded_cell: Vector2i = source_cell + Vector2i(x_offset, y_offset)
				if _is_cell_inside_generation_rect(padded_cell):
					result[padded_cell] = true

	return result


func _is_cell_inside_generation_rect(cell: Vector2i) -> bool:
	var origin: Vector2i = _get_map_origin()
	if cell.x < origin.x or cell.y < origin.y:
		return false
	if cell.x >= origin.x + map_width or cell.y >= origin.y + map_height:
		return false
	return true


func _resolve_terrain_info(tile_set: TileSet, terrain_name: String, fallback_set: int, fallback_terrain: int) -> Vector2i:
	if tile_set == null:
		return Vector2i(fallback_set, fallback_terrain)

	var expected_name: String = terrain_name.strip_edges().to_lower()
	for terrain_set_index: int in range(tile_set.get_terrain_sets_count()):
		for terrain_index: int in range(tile_set.get_terrains_count(terrain_set_index)):
			var current_name: String = tile_set.get_terrain_name(terrain_set_index, terrain_index).strip_edges().to_lower()
			if current_name == expected_name:
				return Vector2i(terrain_set_index, terrain_index)

	push_warning("BattleMapGenerator 找不到 Terrain：%s，将使用 fallback id。" % terrain_name)
	return Vector2i(fallback_set, fallback_terrain)


func _position_spawn_markers(layout: Dictionary) -> void:
	if spawn_points_node == null or battle_map == null:
		return

	var player_spawn_cell: Vector2i = layout.get("player_spawn_cell", Vector2i.ZERO)
	var enemy_spawn_cells: Array[Vector2i] = layout.get("enemy_spawn_cells", [])

	var player_marker: Marker2D = _find_first_marker(true)
	if player_marker != null:
		player_marker.global_position = battle_map.cell_to_world_center(player_spawn_cell)

	var enemy_markers: Array[Marker2D] = _find_enemy_markers()
	for index: int in range(enemy_markers.size()):
		if enemy_spawn_cells.is_empty():
			break
		var spawn_cell: Vector2i = enemy_spawn_cells[index % enemy_spawn_cells.size()]
		enemy_markers[index].global_position = battle_map.cell_to_world_center(spawn_cell)


func _find_first_marker(is_player_marker: bool) -> Marker2D:
	var all_markers: Array[Marker2D] = _collect_markers(spawn_points_node)
	for marker: Marker2D in all_markers:
		var marker_name: String = marker.name.to_lower()
		if is_player_marker and (marker_name.contains("playerspawn") or marker_name.contains("player_spawn")):
			return marker
		if not is_player_marker and (marker_name.contains("enemyspawn") or marker_name.contains("enemy_spawn")):
			return marker
	return null


func _find_enemy_markers() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	var all_markers: Array[Marker2D] = _collect_markers(spawn_points_node)
	for marker: Marker2D in all_markers:
		var marker_name: String = marker.name.to_lower()
		if marker_name.contains("enemyspawn") or marker_name.contains("enemy_spawn"):
			result.append(marker)
	return result


func _collect_markers(root: Node) -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	if root == null:
		return result

	for child: Node in root.get_children():
		if child is Marker2D:
			result.append(child as Marker2D)
		result.append_array(_collect_markers(child))

	return result


func _refresh_battle_map() -> void:
	if battle_map == null:
		return

	battle_map.refresh_layer_cache()
	battle_map.rebuild_navigation_grid()


func _get_player_spawn_target_cell() -> Vector2i:
	var origin: Vector2i = _get_map_origin()
	return Vector2i(
		origin.x + int(round(float(map_width) * 0.20)),
		origin.y + int(round(float(map_height) * 0.50))
	)


func _find_nearest_walkable_cell(target_cell: Vector2i, walkable_cells: Dictionary) -> Vector2i:
	if walkable_cells.has(target_cell):
		return target_cell

	var search_radius: int = max(map_width, map_height)
	for radius: int in range(1, search_radius + 1):
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if abs(x_offset) != radius and abs(y_offset) != radius:
					continue
				var candidate: Vector2i = target_cell + Vector2i(x_offset, y_offset)
				if walkable_cells.has(candidate):
					return candidate

	return _pick_random_walkable_cell(walkable_cells)


func _pick_random_walkable_cell(walkable_cells: Dictionary) -> Vector2i:
	var cells: Array[Vector2i] = _dictionary_keys_to_cells(walkable_cells)
	if cells.is_empty():
		return Vector2i.ZERO
	return cells[rng.randi_range(0, cells.size() - 1)]


func _get_map_origin() -> Vector2i:
	if center_map_on_origin:
		return Vector2i(-int(map_width / 2), -int(map_height / 2))
	return map_origin_override


func _get_cardinal_directions() -> Array[Vector2i]:
	return [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP,
	]
