class_name BattleMap
extends Node2D

## 战斗地图的统一查询入口。
## TileMapLayer 负责视觉与基础格子数据；这个脚本负责把“某处能不能走、哪里能刷怪、脚下是什么地形”等问题统一回答给战斗系统。

const CUSTOM_TERRAIN_TYPE: StringName = &"terrain_type"
const CUSTOM_MOVE_COST: StringName = &"move_cost"
const CUSTOM_TERRAIN_MOTION: StringName = &"terrain_motion"
const CUSTOM_ACCELERATION_MULTIPLIER: StringName = &"acceleration_multiplier"
const CUSTOM_FRICTION_MULTIPLIER: StringName = &"friction_multiplier"
const CUSTOM_TURN_CONTROL_MULTIPLIER: StringName = &"turn_control_multiplier"
const CUSTOM_BLOCKS_MOVEMENT: StringName = &"blocks_movement"
const CUSTOM_BLOCKS_PROJECTILE: StringName = &"blocks_projectile"
const CUSTOM_DAMAGE_PER_SECOND: StringName = &"damage_per_second"
const CUSTOM_STATUS_ID: StringName = &"status_id"
const CUSTOM_SPAWN_TYPE: StringName = &"spawn_type"
const CUSTOM_SPAWN_WEIGHT: StringName = &"spawn_weight"
const CUSTOM_OBJECT_ID: StringName = &"object_id"

const SPAWN_PLAYER: StringName = &"player"
const SPAWN_ENEMY: StringName = &"enemy"
const SPAWN_ANY: StringName = &"any"

@export_group("地图层路径")
## 地面层可以有多个，后面的层优先级更高，例如道路覆盖草地。
@export var ground_layer_paths: Array[NodePath] = [NodePath("GroundLayer"), NodePath("RoadLayer")]
@export var decoration_layer_path: NodePath = NodePath("DecorationLayer")
@export var obstacle_layer_path: NodePath = NodePath("ObstacleLayer")
@export var effect_layer_path: NodePath = NodePath("EffectLayer")
@export var spawn_points_path: NodePath = NodePath("SpawnPoints")
@export var object_spawn_layer_path: NodePath = NodePath("ObjectSpawnLayer")
@export var object_container_path: NodePath = NodePath("ObjectContainer")
@export var runtime_effect_container_path: NodePath = NodePath("RuntimeEffectContainer")
## 模板地图中用于手工框选随机生成范围的节点容器。
@export var random_areas_path: NodePath = NodePath("RandomAreas")

@export_group("通行规则")
## 开启后，没有地面瓦片的格子会被视为地图外，不能行走。
@export var require_ground_tile_for_walkable: bool = true
## 障碍层上的瓦片默认阻挡移动；如果瓦片 custom data 写了 blocks_movement，则以 custom data 为准。
@export var obstacle_tiles_block_by_default: bool = true
## 障碍层上的瓦片默认阻挡投射物；柱子、墙体这类障碍会更符合直觉。
@export var obstacle_tiles_block_projectiles_by_default: bool = true
## EffectLayer 上的瓦片默认不阻挡移动，只有 custom data 显式 blocks_movement=true 才阻挡。
@export var effect_tiles_block_by_default: bool = false
## 关闭地面、装饰和特效层的物理碰撞，避免非障碍瓦片误挡实体。
@export var disable_non_obstacle_tile_collisions: bool = true
## 是否保留 ObstacleLayer 的物理碰撞。逻辑层的 blocks_movement 不受此开关影响。
@export var obstacle_collision_enabled: bool = true
## 是否用手动 Rect2i 作为地图边界。不开启时，会用地面层、障碍层、特效层的已使用格子自动计算。
@export var use_bounds_override: bool = false
@export var bounds_override: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)

@export_group("随机点")
@export var random_spawn_max_attempts: int = 80
## 随机刷怪点与参考点之间的默认最小距离，通常传玩家位置作为参考点。
@export var default_enemy_spawn_min_distance: float = 220.0

@export_group("寻路")
## 开启后，BattleMap 会在 ready 时根据瓦片数据构建 AStarGrid2D。
@export var build_navigation_on_ready: bool = true
## 允许斜向寻路，但会避免从两个障碍物夹角里“挤过去”。
@export var allow_diagonal_navigation: bool = true
## 目标点暂时不可达时，是否允许返回一条尽量接近目标的路径。
@export var navigation_allow_partial_path: bool = true
## 起点或终点落在不可走格子时，向外搜索最近可走格子的范围。
@export var nearest_walkable_cell_search_radius: int = 5
## 障碍周围多少格会被视为“贴墙危险区”。用于让敌人路径离墙角远一点，减少身体卡墙。
@export var navigation_obstacle_padding_cells: int = 1
## 开启后危险区会被直接视为不可走；关闭时只提高权重，保留窄路可通行性。
@export var navigation_padding_as_solid: bool = false
## 危险区的寻路权重。数值越高，AI 越不愿意贴墙走。
@export var navigation_padding_weight: float = 4.0
@export_group("绘制排序")
## 开启后，障碍、装饰和地图物件会按 y 坐标参与纵深排序。
@export var enable_depth_y_sort: bool = true
## 地面类图层固定在角色与障碍下方，不参与遮挡。
@export var ground_depth_z_index: int = -100
@export var road_depth_z_index: int = -90
@export var effect_depth_z_index: int = -80
## 山丘、装饰、地图物件与实体处于同一 z 层，再交给 y-sort 决定前后。
@export var depth_sorted_z_index: int = 0

var ground_layers: Array[TileMapLayer] = []
var decoration_layer: TileMapLayer
var obstacle_layer: TileMapLayer
var effect_layer: TileMapLayer
var spawn_points_layer: TileMapLayer
var spawn_points_node: Node
var object_spawn_layer: TileMapLayer
var object_container: Node
var runtime_effect_container: Node
var random_areas_node: Node
var navigation_grid: AStarGrid2D
var navigation_bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
var navigation_ready: bool = false
var runtime_navigation_blockers_by_cell: Dictionary = {}
var runtime_navigation_cells_by_blocker: Dictionary = {}
var runtime_navigation_previous_solid_by_cell: Dictionary = {}
var custom_data_layer_exists_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("battle_map")
	refresh_layer_cache()
	configure_depth_sorting()
	if build_navigation_on_ready:
		rebuild_navigation_grid()


## 重新查找并缓存各个层。以后如果运行时替换地图层，可以调用它刷新引用。
func refresh_layer_cache() -> void:
	custom_data_layer_exists_cache.clear()
	ground_layers.clear()
	for layer_path: NodePath in ground_layer_paths:
		var layer: TileMapLayer = get_node_or_null(layer_path) as TileMapLayer
		if layer != null:
			ground_layers.append(layer)

	decoration_layer = get_node_or_null(decoration_layer_path) as TileMapLayer
	obstacle_layer = get_node_or_null(obstacle_layer_path) as TileMapLayer
	effect_layer = get_node_or_null(effect_layer_path) as TileMapLayer
	spawn_points_node = get_node_or_null(spawn_points_path)
	spawn_points_layer = spawn_points_node as TileMapLayer
	object_spawn_layer = get_node_or_null(object_spawn_layer_path) as TileMapLayer
	object_container = get_node_or_null(object_container_path)
	runtime_effect_container = get_node_or_null(runtime_effect_container_path)
	random_areas_node = get_node_or_null(random_areas_path)
	_configure_tile_layer_collisions()
	configure_depth_sorting()


func _configure_tile_layer_collisions() -> void:
	# 装饰 TileSet 可能带有碰撞形状，但它不应承担地图的阻挡职责。
	if not disable_non_obstacle_tile_collisions:
		return

	for ground_layer: TileMapLayer in ground_layers:
		ground_layer.collision_enabled = false
	if decoration_layer != null:
		decoration_layer.collision_enabled = false
	if effect_layer != null:
		effect_layer.collision_enabled = false
	if object_spawn_layer != null:
		object_spawn_layer.collision_enabled = false
	if obstacle_layer != null:
		obstacle_layer.collision_enabled = obstacle_collision_enabled


## 配置战斗地图的绘制层级。
## Ground/Road/Effect 是地面信息；Obstacle/Decoration/ObjectContainer 则用 y-sort 营造“人在物体前后移动”的纵深。
func configure_depth_sorting() -> void:
	if not enable_depth_y_sort:
		return

	y_sort_enabled = true
	z_index = depth_sorted_z_index
	z_as_relative = true

	for index: int in range(ground_layers.size()):
		var ground_layer: TileMapLayer = ground_layers[index]
		_configure_layer_depth(ground_layer, ground_depth_z_index + index, false)

	_configure_layer_depth(effect_layer, effect_depth_z_index, false)
	_configure_layer_depth(decoration_layer, depth_sorted_z_index, true)
	_configure_layer_depth(obstacle_layer, depth_sorted_z_index, true)
	_configure_y_sorted_container(object_container)
	_configure_y_sorted_container(runtime_effect_container)


func _configure_layer_depth(layer: TileMapLayer, new_z_index: int, use_y_sort: bool) -> void:
	if layer == null:
		return

	layer.z_index = new_z_index
	layer.z_as_relative = true
	layer.y_sort_enabled = use_y_sort


func _configure_y_sorted_container(container: Node) -> void:
	var container_node: Node2D = container as Node2D
	if container_node == null:
		return

	container_node.z_index = depth_sorted_z_index
	container_node.z_as_relative = true
	container_node.y_sort_enabled = true


## 返回玩家出生点。优先读 Marker2D，其次读 SpawnPoints 瓦片，最后回退到地图中心。
func get_player_spawn_position(default_position: Vector2 = Vector2.ZERO) -> Vector2:
	# 出生点配置错误时，不直接把玩家放进墙里，依次尝试最近的安全位置。
	var marker_positions: Array[Vector2] = _collect_marker_spawn_positions(SPAWN_PLAYER)
	for marker_position: Vector2 in marker_positions:
		if is_world_position_walkable(marker_position):
			return marker_position

	var tile_positions: Array[Vector2] = _collect_tile_spawn_positions(SPAWN_PLAYER)
	for tile_position: Vector2 in tile_positions:
		if is_world_position_walkable(tile_position):
			return tile_position

	var map_center: Variant = get_map_center_world()
	if map_center is Vector2 and is_world_position_walkable(map_center as Vector2):
		return map_center as Vector2

	var nearest_position: Variant = get_nearest_walkable_position(default_position, nearest_walkable_cell_search_radius)
	if nearest_position is Vector2:
		return nearest_position as Vector2

	return default_position


## 返回一个敌人出生点。优先读 SpawnPoints；没有配置时，从可行走地面随机挑。
func get_random_enemy_spawn_position(
	reference_position: Vector2 = Vector2.ZERO,
	min_distance: float = -1.0,
	default_position: Vector2 = Vector2.ZERO
) -> Vector2:
	var resolved_min_distance: float = default_enemy_spawn_min_distance if min_distance < 0.0 else min_distance
	var candidates: Array[Vector2] = _collect_spawn_positions(SPAWN_ENEMY)
	candidates.append_array(_collect_spawn_positions(SPAWN_ANY))
	candidates = _filter_walkable_positions(candidates, reference_position, resolved_min_distance)

	if not candidates.is_empty():
		return candidates[randi_range(0, candidates.size() - 1)]

	var random_position: Variant = get_random_walkable_position(reference_position, resolved_min_distance)
	if random_position is Vector2:
		return random_position

	return default_position


## 从地面层里随机找一个可行走点。适合生成地图物件、掉落物、额外刷怪等。
func get_random_walkable_position(reference_position: Vector2 = Vector2.ZERO, min_distance: float = 0.0) -> Variant:
	var cells: Array[Vector2i] = _collect_candidate_ground_cells()
	if cells.is_empty():
		return null

	for _attempt: int in range(max(random_spawn_max_attempts, 1)):
		var cell: Vector2i = cells[randi_range(0, cells.size() - 1)]
		var world_position: Vector2 = cell_to_world_center(cell)
		if not is_world_position_walkable(world_position):
			continue
		if min_distance > 0.0 and reference_position != Vector2.ZERO:
			if world_position.distance_to(reference_position) < min_distance:
				continue
		return world_position

	return null


## 模板地图可以摆 BattleMapRandomArea 来限制随机物体的大致出现范围。
## 如果没有可用区域，调用方应回退到 get_random_walkable_position，保证旧地图仍能工作。
func get_random_map_object_spawn_position(object_id: StringName, max_attempts: int = 80) -> Variant:
	var areas: Array[BattleMapRandomArea] = get_random_map_object_areas(object_id)
	if areas.is_empty():
		return null

	var attempts: int = max(max_attempts, 1)
	var per_area_attempts: int = int(clamp(float(attempts) / 4.0, 4.0, 20.0))
	for _attempt: int in range(attempts):
		var area: BattleMapRandomArea = _pick_weighted_random_area(areas)
		if area == null:
			return null

		var position_value: Variant = area.get_random_walkable_position(self, per_area_attempts)
		if position_value is Vector2:
			return position_value

	return null


func has_map_object_random_areas(object_id: StringName) -> bool:
	return not get_random_map_object_areas(object_id).is_empty()


func get_random_map_object_areas(object_id: StringName) -> Array[BattleMapRandomArea]:
	var result: Array[BattleMapRandomArea] = []
	var areas: Array[BattleMapRandomArea] = get_random_areas(BattleMapRandomArea.AreaType.MAP_OBJECT)
	for area: BattleMapRandomArea in areas:
		if area.can_spawn_object(object_id):
			result.append(area)
	return result


func get_random_areas(area_type: int) -> Array[BattleMapRandomArea]:
	var result: Array[BattleMapRandomArea] = []
	if random_areas_node == null:
		return result

	_collect_random_areas_recursive(random_areas_node, area_type, result)
	return result


## 返回指定类型的出生点，供随机地图物件避开玩家/敌人出生区域。
func get_spawn_positions(spawn_type: StringName) -> Array[Vector2]:
	return _collect_spawn_positions(spawn_type)


## 返回当前地图中所有可行走格，供地图生成验证器和调试工具使用。
func get_walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _collect_candidate_ground_cells():
		if is_world_position_walkable(cell_to_world_center(cell)):
			result.append(cell)
	return result


## 从指定位置向外寻找最近的可行走格，适合修正错误的出生点。
func get_nearest_walkable_position(world_position: Vector2, search_radius: int = 5) -> Variant:
	var origin_cell: Vector2i = world_to_cell(world_position)
	var radius_limit: int = max(search_radius, 0)
	for radius: int in range(0, radius_limit + 1):
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if radius > 0 and abs(x_offset) < radius and abs(y_offset) < radius:
					continue

				var candidate_cell: Vector2i = origin_cell + Vector2i(x_offset, y_offset)
				var candidate_position: Vector2 = cell_to_world_center(candidate_cell)
				if is_world_position_walkable(candidate_position):
					return candidate_position

	return null


## 判断世界坐标是否在地图边界内。
func is_world_position_inside_bounds(world_position: Vector2) -> bool:
	var bounds: Rect2i = get_map_bounds_cells()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return true

	var cell: Vector2i = world_to_cell(world_position)
	return _rect_has_cell(bounds, cell)


## 判断世界坐标是否可行走。当前项目角色移动还不是物理移动时，可以先用它在移动前做逻辑拦截。
func is_world_position_walkable(world_position: Vector2) -> bool:
	if not is_world_position_inside_bounds(world_position):
		return false

	var cell: Vector2i = world_to_cell(world_position)
	if _is_runtime_navigation_blocked(cell):
		return false
	if require_ground_tile_for_walkable and not _has_ground_tile(cell):
		return false

	if _cell_blocks_movement(obstacle_layer, cell, obstacle_tiles_block_by_default):
		return false
	if _cell_blocks_movement(effect_layer, cell, effect_tiles_block_by_default):
		return false

	for ground_layer: TileMapLayer in ground_layers:
		if _cell_blocks_movement(ground_layer, cell, false):
			return false

	return true


## 判断世界坐标是否阻挡投射物。之后 projectile/manifest 可以用它处理墙体、柱子挡弹。
func blocks_projectile(world_position: Vector2) -> bool:
	if not is_world_position_inside_bounds(world_position):
		return true

	var cell: Vector2i = world_to_cell(world_position)
	if _cell_blocks_projectile(obstacle_layer, cell, obstacle_tiles_block_projectiles_by_default):
		return true
	if _cell_blocks_projectile(effect_layer, cell, false):
		return true

	return false


## 获取脚下地形类型。EffectLayer 可以覆盖 GroundLayer，例如岩浆覆盖草地。
func get_terrain_type(world_position: Vector2, default_type: StringName = &"") -> StringName:
	var cell: Vector2i = world_to_cell(world_position)
	var effect_type: StringName = _get_custom_string_name(_get_tile_data(effect_layer, cell), CUSTOM_TERRAIN_TYPE, &"")
	if effect_type != &"":
		return effect_type

	for index: int in range(ground_layers.size() - 1, -1, -1):
		var terrain_type: StringName = _get_custom_string_name(_get_tile_data(ground_layers[index], cell), CUSTOM_TERRAIN_TYPE, &"")
		if terrain_type != &"":
			return terrain_type

	return default_type


## 获取脚下移动消耗。AStarGrid2D 会用它做路径权重，Entity 也会用它修正实际移动速度。
func get_move_cost(world_position: Vector2, default_cost: float = 1.0) -> float:
	var cell: Vector2i = world_to_cell(world_position)
	var effect_cost: Variant = _get_custom_data(_get_tile_data(effect_layer, cell), CUSTOM_MOVE_COST)
	if effect_cost != null:
		return max(float(effect_cost), 0.0)

	for index: int in range(ground_layers.size() - 1, -1, -1):
		var ground_cost: Variant = _get_custom_data(_get_tile_data(ground_layers[index], cell), CUSTOM_MOVE_COST)
		if ground_cost != null:
			return max(float(ground_cost), 0.0)

	return default_cost


## 获取脚下地形的“移动手感”参数。
## EffectLayer 优先级最高；如果特效层没有运动参数，则回退到地面层。
## 冰面只要 terrain_type 写成 ice_ground / ice，就会自动套用默认冰面惯性。
func get_terrain_motion_profile(world_position: Vector2) -> Dictionary:
	var cell: Vector2i = world_to_cell(world_position)
	var effect_profile: Dictionary = _get_terrain_motion_profile_from_cell(effect_layer, cell)
	if not effect_profile.is_empty():
		return effect_profile

	for index: int in range(ground_layers.size() - 1, -1, -1):
		var ground_profile: Dictionary = _get_terrain_motion_profile_from_cell(ground_layers[index], cell)
		if not ground_profile.is_empty():
			return ground_profile

	return _make_terrain_motion_profile(&"normal", 1.0, 1.0, 1.0)


## 获取脚下每秒伤害。地形效果控制器后续可以直接读取它。
func get_damage_per_second(world_position: Vector2, default_damage: float = 0.0) -> float:
	var cell: Vector2i = world_to_cell(world_position)
	var damage_value: Variant = _get_custom_data(_get_tile_data(effect_layer, cell), CUSTOM_DAMAGE_PER_SECOND)
	if damage_value == null:
		return default_damage
	return max(float(damage_value), 0.0)


## 获取脚下地形附加状态 id，例如 poison、frost_slow。
func get_status_id(world_position: Vector2, default_status: StringName = &"") -> StringName:
	var cell: Vector2i = world_to_cell(world_position)
	return _get_custom_string_name(_get_tile_data(effect_layer, cell), CUSTOM_STATUS_ID, default_status)


## 世界坐标转地图格子。所有地图层应保持同一格子尺寸与原点。
func world_to_cell(world_position: Vector2) -> Vector2i:
	var reference_layer: TileMapLayer = _get_reference_layer()
	if reference_layer == null:
		return Vector2i.ZERO

	return reference_layer.local_to_map(reference_layer.to_local(world_position))


## 地图格子转世界坐标中心点。
func cell_to_world_center(cell: Vector2i) -> Vector2:
	var reference_layer: TileMapLayer = _get_reference_layer()
	if reference_layer == null:
		return global_position

	return reference_layer.to_global(reference_layer.map_to_local(cell))


## 获取自动计算或手动覆盖后的地图边界。
func get_map_bounds_cells() -> Rect2i:
	if use_bounds_override:
		return bounds_override

	var has_bounds: bool = false
	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = 0
	var max_y: int = 0

	for layer: TileMapLayer in _get_bounds_layers():
		for cell_value in layer.get_used_cells():
			var cell: Vector2i = cell_value
			if not has_bounds:
				min_x = cell.x
				max_x = cell.x
				min_y = cell.y
				max_y = cell.y
				has_bounds = true
				continue

			min_x = min(min_x, cell.x)
			max_x = max(max_x, cell.x)
			min_y = min(min_y, cell.y)
			max_y = max(max_y, cell.y)

	if not has_bounds:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


## 获取地图中心世界坐标。没有任何瓦片时返回 null。
func get_map_center_world() -> Variant:
	var bounds: Rect2i = get_map_bounds_cells()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return null

	var center_cell: Vector2i = bounds.position + Vector2i(bounds.size.x / 2, bounds.size.y / 2)
	return cell_to_world_center(center_cell)


func get_object_container() -> Node:
	return object_container


func get_object_spawn_layer() -> TileMapLayer:
	return object_spawn_layer


func get_runtime_effect_container() -> Node:
	return runtime_effect_container


## 注册运行时生成的导航阻挡物，例如石头、宝箱、临时墙体。
## 它只影响 AStarGrid2D 和逻辑可行走判断；真正的物理阻挡仍然由物件自己的 CollisionShape2D 负责。
func register_runtime_navigation_blocker(blocker: Node, world_position: Vector2, radius_cells: int = 0) -> void:
	if blocker == null:
		return

	unregister_runtime_navigation_blocker(blocker)
	var blocker_id: int = blocker.get_instance_id()
	var center_cell: Vector2i = world_to_cell(world_position)
	var cells: Array[Vector2i] = _collect_runtime_navigation_block_cells(center_cell, radius_cells)
	if cells.is_empty():
		return

	runtime_navigation_cells_by_blocker[blocker_id] = cells
	for cell: Vector2i in cells:
		var blockers: Dictionary = runtime_navigation_blockers_by_cell.get(cell, {})
		blockers[blocker_id] = true
		runtime_navigation_blockers_by_cell[cell] = blockers
		_set_runtime_navigation_cell_blocked(cell, true)


## 解除某个运行时阻挡物占用的格子。多个物件占同一格时，会等最后一个物件移除后才真正放开。
func unregister_runtime_navigation_blocker(blocker: Node) -> void:
	if blocker == null:
		return

	var blocker_id: int = blocker.get_instance_id()
	var cells_value: Variant = runtime_navigation_cells_by_blocker.get(blocker_id)
	if not (cells_value is Array):
		return

	runtime_navigation_cells_by_blocker.erase(blocker_id)
	for cell_value in cells_value:
		var cell: Vector2i = cell_value
		var blockers: Dictionary = runtime_navigation_blockers_by_cell.get(cell, {})
		blockers.erase(blocker_id)

		if blockers.is_empty():
			runtime_navigation_blockers_by_cell.erase(cell)
			_restore_runtime_navigation_cell(cell)
		else:
			runtime_navigation_blockers_by_cell[cell] = blockers


## 根据当前 TileMapLayer 的 custom data 重建 AStarGrid2D。
## 之后如果运行时生成/移除障碍物，可以在改完瓦片后主动调用这个函数。
func rebuild_navigation_grid() -> void:
	navigation_ready = false
	navigation_grid = null
	runtime_navigation_previous_solid_by_cell.clear()
	navigation_bounds = get_map_bounds_cells()
	if navigation_bounds.size.x <= 0 or navigation_bounds.size.y <= 0:
		return

	navigation_grid = AStarGrid2D.new()
	navigation_grid.region = navigation_bounds
	navigation_grid.cell_size = _get_reference_cell_size()
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES if allow_diagonal_navigation else AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation_grid.update()

	var blocked_cells: Dictionary = {}
	for y: int in range(navigation_bounds.position.y, navigation_bounds.position.y + navigation_bounds.size.y):
		for x: int in range(navigation_bounds.position.x, navigation_bounds.position.x + navigation_bounds.size.x):
			var cell: Vector2i = Vector2i(x, y)
			if not _is_cell_static_walkable_for_navigation(cell):
				navigation_grid.set_point_solid(cell, true)
				blocked_cells[cell] = true
				continue

			var world_position: Vector2 = cell_to_world_center(cell)
			var move_cost: float = max(get_move_cost(world_position, 1.0), 0.01)
			navigation_grid.set_point_weight_scale(cell, move_cost)

	_apply_navigation_obstacle_padding(blocked_cells)
	_apply_runtime_navigation_blockers_to_grid()
	navigation_ready = true


func has_navigation_grid() -> bool:
	return navigation_ready and navigation_grid != null


## 返回从 start_world 到 target_world 的世界坐标路径。
## 路径点使用格子中心点，调用者通常只需要取第二个点作为移动方向。
func get_navigation_path(start_world: Vector2, target_world: Vector2) -> PackedVector2Array:
	if not has_navigation_grid():
		if build_navigation_on_ready:
			rebuild_navigation_grid()
		if not has_navigation_grid():
			return PackedVector2Array()

	var start_cell_value: Variant = _resolve_navigation_cell(world_to_cell(start_world))
	var target_cell_value: Variant = _resolve_navigation_cell(world_to_cell(target_world))
	if not (start_cell_value is Vector2i) or not (target_cell_value is Vector2i):
		return PackedVector2Array()

	var start_cell: Vector2i = start_cell_value
	var target_cell: Vector2i = target_cell_value
	if start_cell == target_cell:
		return PackedVector2Array([target_world])

	var id_path: Array = navigation_grid.get_id_path(start_cell, target_cell, navigation_allow_partial_path)
	if id_path.is_empty():
		return PackedVector2Array()

	var world_path: PackedVector2Array = PackedVector2Array()
	for cell_value in id_path:
		var cell: Vector2i = cell_value
		world_path.append(cell_to_world_center(cell))

	return world_path


## 直接返回下一步移动方向。敌人/召唤物可以通过这个接口隐藏 AStarGrid2D 的细节。
func get_navigation_direction(start_world: Vector2, target_world: Vector2, arrive_distance: float = 8.0) -> Vector2:
	var next_point_value: Variant = get_next_navigation_point(start_world, target_world, arrive_distance)
	if next_point_value is Vector2:
		return start_world.direction_to(next_point_value)

	return Vector2.ZERO


## 返回下一路径点的世界坐标。需要把寻路向量和避让力混合时，用这个比单位方向更稳定。
func get_next_navigation_point(start_world: Vector2, target_world: Vector2, arrive_distance: float = 8.0) -> Variant:
	var path: PackedVector2Array = get_navigation_path(start_world, target_world)
	if path.is_empty():
		return null

	for point: Vector2 in path:
		if start_world.distance_to(point) > arrive_distance:
			return point

	return target_world


func _collect_spawn_positions(spawn_type: StringName) -> Array[Vector2]:
	var result: Array[Vector2] = []
	result.append_array(_collect_marker_spawn_positions(spawn_type))
	result.append_array(_collect_tile_spawn_positions(spawn_type))
	return result


func _collect_random_areas_recursive(node: Node, area_type: int, result: Array[BattleMapRandomArea]) -> void:
	for child: Node in node.get_children():
		var area: BattleMapRandomArea = child as BattleMapRandomArea
		if area != null and area.matches_area_type(area_type):
			result.append(area)

		_collect_random_areas_recursive(child, area_type, result)


func _pick_weighted_random_area(areas: Array[BattleMapRandomArea]) -> BattleMapRandomArea:
	var total_weight: float = 0.0
	for area: BattleMapRandomArea in areas:
		if area == null or not area.enabled:
			continue
		total_weight += max(area.weight, 0.0)

	if total_weight <= 0.0:
		return null

	var roll: float = randf() * total_weight
	var cursor: float = 0.0
	for area: BattleMapRandomArea in areas:
		if area == null or not area.enabled:
			continue

		cursor += max(area.weight, 0.0)
		if roll <= cursor:
			return area

	var fallback_area: BattleMapRandomArea = areas[areas.size() - 1]
	return fallback_area


func _collect_marker_spawn_positions(spawn_type: StringName) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if spawn_points_node == null:
		return result

	_collect_marker_spawn_positions_recursive(spawn_points_node, spawn_type, result)
	return result


func _collect_marker_spawn_positions_recursive(node: Node, spawn_type: StringName, result: Array[Vector2]) -> void:
	for child: Node in node.get_children():
		if child is Marker2D and _marker_matches_spawn(child as Marker2D, spawn_type):
			result.append((child as Marker2D).global_position)

		_collect_marker_spawn_positions_recursive(child, spawn_type, result)


func _marker_matches_spawn(marker: Marker2D, spawn_type: StringName) -> bool:
	var marker_name: String = marker.name.to_lower()
	if spawn_type == SPAWN_PLAYER:
		return marker_name.contains("playerspawn") or marker_name.contains("player_spawn") or marker.is_in_group("player_spawn")
	if spawn_type == SPAWN_ENEMY:
		return marker_name.contains("enemyspawn") or marker_name.contains("enemy_spawn") or marker.is_in_group("enemy_spawn")
	if spawn_type == SPAWN_ANY:
		return marker_name.contains("spawn") or marker.is_in_group("battle_spawn")
	return false


func _collect_tile_spawn_positions(spawn_type: StringName) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if spawn_points_layer == null:
		return result

	for cell_value in spawn_points_layer.get_used_cells():
		var cell: Vector2i = cell_value
		var tile_data: TileData = _get_tile_data(spawn_points_layer, cell)
		var tile_spawn_type: StringName = _get_custom_string_name(tile_data, CUSTOM_SPAWN_TYPE, &"")
		if _tile_spawn_type_matches(tile_spawn_type, spawn_type):
			result.append(spawn_points_layer.to_global(spawn_points_layer.map_to_local(cell)))

	return result


func _find_marker_position_for_spawn(spawn_type: StringName) -> Variant:
	var positions: Array[Vector2] = _collect_marker_spawn_positions(spawn_type)
	if positions.is_empty():
		return null
	return positions[0]


func _find_first_spawn_tile_position(spawn_type: StringName) -> Variant:
	var positions: Array[Vector2] = _collect_tile_spawn_positions(spawn_type)
	if positions.is_empty():
		return null
	return positions[0]


func _tile_spawn_type_matches(tile_spawn_type: StringName, expected_type: StringName) -> bool:
	if tile_spawn_type == expected_type:
		return true
	if expected_type == SPAWN_ENEMY and tile_spawn_type == &"":
		return true
	if expected_type == SPAWN_ANY and tile_spawn_type == SPAWN_ANY:
		return true
	return false


func _filter_walkable_positions(source_positions: Array[Vector2], reference_position: Vector2, min_distance: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for position: Vector2 in source_positions:
		if not is_world_position_walkable(position):
			continue
		if min_distance > 0.0 and reference_position != Vector2.ZERO:
			if position.distance_to(reference_position) < min_distance:
				continue
		result.append(position)
	return result


func _collect_candidate_ground_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen_cells: Dictionary = {}
	for layer: TileMapLayer in ground_layers:
		for cell_value in layer.get_used_cells():
			var cell: Vector2i = cell_value
			var key: String = "%s:%s" % [cell.x, cell.y]
			if seen_cells.has(key):
				continue
			seen_cells[key] = true
			result.append(cell)
	return result


func _has_ground_tile(cell: Vector2i) -> bool:
	for layer: TileMapLayer in ground_layers:
		if _get_tile_data(layer, cell) != null:
			return true
	return false


func _is_cell_walkable_for_navigation(cell: Vector2i) -> bool:
	if _is_runtime_navigation_blocked(cell):
		return false
	return _is_cell_static_walkable_for_navigation(cell)


func _is_cell_static_walkable_for_navigation(cell: Vector2i) -> bool:
	if require_ground_tile_for_walkable and not _has_ground_tile(cell):
		return false

	if _cell_blocks_movement(obstacle_layer, cell, obstacle_tiles_block_by_default):
		return false
	if _cell_blocks_movement(effect_layer, cell, effect_tiles_block_by_default):
		return false

	for ground_layer: TileMapLayer in ground_layers:
		if _cell_blocks_movement(ground_layer, cell, false):
			return false

	return true


func _is_runtime_navigation_blocked(cell: Vector2i) -> bool:
	var blockers: Dictionary = runtime_navigation_blockers_by_cell.get(cell, {})
	return not blockers.is_empty()


func _collect_runtime_navigation_block_cells(center_cell: Vector2i, radius_cells: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var radius: int = max(radius_cells, 0)
	for y_offset: int in range(-radius, radius + 1):
		for x_offset: int in range(-radius, radius + 1):
			result.append(center_cell + Vector2i(x_offset, y_offset))
	return result


func _set_runtime_navigation_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	if navigation_grid == null:
		return
	if not navigation_grid.is_in_boundsv(cell):
		return

	if blocked:
		if not runtime_navigation_previous_solid_by_cell.has(cell):
			runtime_navigation_previous_solid_by_cell[cell] = navigation_grid.is_point_solid(cell)
		navigation_grid.set_point_solid(cell, true)
	else:
		_restore_runtime_navigation_cell(cell)


func _restore_runtime_navigation_cell(cell: Vector2i) -> void:
	if navigation_grid == null:
		runtime_navigation_previous_solid_by_cell.erase(cell)
		return
	if not navigation_grid.is_in_boundsv(cell):
		runtime_navigation_previous_solid_by_cell.erase(cell)
		return

	var previous_solid: bool = bool(runtime_navigation_previous_solid_by_cell.get(cell, false))
	runtime_navigation_previous_solid_by_cell.erase(cell)
	navigation_grid.set_point_solid(cell, previous_solid)


func _apply_runtime_navigation_blockers_to_grid() -> void:
	for cell_value in runtime_navigation_blockers_by_cell.keys():
		var cell: Vector2i = cell_value
		_set_runtime_navigation_cell_blocked(cell, true)


func _apply_navigation_obstacle_padding(blocked_cells: Dictionary) -> void:
	if navigation_grid == null:
		return
	if navigation_obstacle_padding_cells <= 0:
		return

	var radius: int = max(navigation_obstacle_padding_cells, 0)
	var applied_cells: Dictionary = {}
	for blocked_cell_value in blocked_cells.keys():
		var blocked_cell: Vector2i = blocked_cell_value
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if x_offset == 0 and y_offset == 0:
					continue

				var candidate: Vector2i = blocked_cell + Vector2i(x_offset, y_offset)
				if applied_cells.has(candidate):
					continue
				if not _is_navigation_cell_walkable(candidate):
					continue

				applied_cells[candidate] = true
				if navigation_padding_as_solid:
					navigation_grid.set_point_solid(candidate, true)
					continue

				var current_weight: float = navigation_grid.get_point_weight_scale(candidate)
				navigation_grid.set_point_weight_scale(candidate, max(current_weight, navigation_padding_weight))


func _cell_blocks_movement(layer: TileMapLayer, cell: Vector2i, default_when_tile_exists: bool) -> bool:
	var tile_data: TileData = _get_tile_data(layer, cell)
	if tile_data == null:
		return false

	return _get_custom_bool(tile_data, CUSTOM_BLOCKS_MOVEMENT, default_when_tile_exists)


func _cell_blocks_projectile(layer: TileMapLayer, cell: Vector2i, default_when_tile_exists: bool) -> bool:
	var tile_data: TileData = _get_tile_data(layer, cell)
	if tile_data == null:
		return false

	return _get_custom_bool(tile_data, CUSTOM_BLOCKS_PROJECTILE, default_when_tile_exists)


func _get_tile_data(layer: TileMapLayer, cell: Vector2i) -> TileData:
	if layer == null:
		return null
	return layer.get_cell_tile_data(cell)


func _get_custom_data(tile_data: TileData, key: StringName) -> Variant:
	if tile_data == null:
		return null
	return tile_data.get_custom_data(key)


func _get_custom_bool(tile_data: TileData, key: StringName, default_value: bool) -> bool:
	var value: Variant = _get_custom_data(tile_data, key)
	if value == null:
		return default_value
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return float(value) != 0.0

	var text: String = str(value).to_lower()
	return text == "true" or text == "1" or text == "yes"


func _get_custom_float(tile_data: TileData, key: StringName, default_value: float) -> float:
	var value: Variant = _get_custom_data(tile_data, key)
	if value == null:
		return default_value
	if value is float or value is int:
		var numeric_value: float = float(value)
		# 0 通常代表“该瓦片没有填写此倍率”，不应把默认移动参数清零。
		return default_value if is_zero_approx(numeric_value) else numeric_value

	var text: String = str(value)
	if text.is_valid_float():
		var parsed_value: float = text.to_float()
		return default_value if is_zero_approx(parsed_value) else parsed_value
	return default_value


func _has_meaningful_motion_value(value: Variant) -> bool:
	if value == null:
		return false
	if value is float or value is int:
		return not is_zero_approx(float(value))

	var text: String = str(value).strip_edges()
	if text.is_valid_float():
		return not is_zero_approx(text.to_float())
	return not text.is_empty()


func _get_layer_custom_data(layer: TileMapLayer, cell: Vector2i, key: StringName) -> Variant:
	if layer == null or layer.tile_set == null:
		return null
	if not _layer_has_custom_data(layer, key):
		return null

	var tile_data: TileData = _get_tile_data(layer, cell)
	if tile_data == null:
		return null
	return tile_data.get_custom_data(key)


func _get_layer_custom_float(layer: TileMapLayer, cell: Vector2i, key: StringName, default_value: float) -> float:
	var value: Variant = _get_layer_custom_data(layer, cell, key)
	if value == null:
		return default_value
	if value is float or value is int:
		return float(value)

	var text: String = str(value)
	if text.is_valid_float():
		return text.to_float()
	return default_value


func _get_layer_custom_string_name(layer: TileMapLayer, cell: Vector2i, key: StringName, default_value: StringName) -> StringName:
	var value: Variant = _get_layer_custom_data(layer, cell, key)
	if value == null:
		return default_value

	var text: String = str(value)
	if text.is_empty():
		return default_value
	return StringName(text)


func _layer_has_custom_data(layer: TileMapLayer, key: StringName) -> bool:
	if layer == null or layer.tile_set == null:
		return false

	var cache_key: String = "%s:%s" % [layer.tile_set.get_instance_id(), String(key)]
	if custom_data_layer_exists_cache.has(cache_key):
		return bool(custom_data_layer_exists_cache[cache_key])

	var has_layer: bool = false
	for layer_index: int in range(layer.tile_set.get_custom_data_layers_count()):
		var layer_name: StringName = StringName(layer.tile_set.get_custom_data_layer_name(layer_index))
		if layer_name == key:
			has_layer = true
			break

	custom_data_layer_exists_cache[cache_key] = has_layer
	return has_layer


func _get_custom_string_name(tile_data: TileData, key: StringName, default_value: StringName) -> StringName:
	var value: Variant = _get_custom_data(tile_data, key)
	if value == null:
		return default_value

	var text: String = str(value)
	if text.is_empty():
		return default_value
	return StringName(text)


func _get_terrain_motion_profile_from_cell(layer: TileMapLayer, cell: Vector2i) -> Dictionary:
	if layer == null:
		return {}

	var tile_data: TileData = _get_tile_data(layer, cell)
	if tile_data == null:
		return {}

	var terrain_type: StringName = _get_layer_custom_string_name(layer, cell, CUSTOM_TERRAIN_TYPE, &"")
	var explicit_acceleration_value: Variant = _get_layer_custom_data(layer, cell, CUSTOM_ACCELERATION_MULTIPLIER)
	var explicit_friction_value: Variant = _get_layer_custom_data(layer, cell, CUSTOM_FRICTION_MULTIPLIER)
	var explicit_turn_value: Variant = _get_layer_custom_data(layer, cell, CUSTOM_TURN_CONTROL_MULTIPLIER)
	var motion_id: StringName = _get_layer_custom_string_name(layer, cell, CUSTOM_TERRAIN_MOTION, &"")

	if motion_id == &"":
		motion_id = _get_default_motion_id_for_terrain(terrain_type)

	# TileSet 添加了自定义数据层后，普通瓦片未填写的浮点数据会读成 0。
	# 这里不能把这个默认 0 当成“将移动加速度设为 0”，否则整张模板会无法移动。
	var has_motion_data: bool = motion_id != &""
	if not has_motion_data:
		has_motion_data = _has_meaningful_motion_value(explicit_acceleration_value)
		has_motion_data = has_motion_data or _has_meaningful_motion_value(explicit_friction_value)
		has_motion_data = has_motion_data or _has_meaningful_motion_value(explicit_turn_value)
	if not has_motion_data:
		return {}

	if motion_id == &"":
		motion_id = &"normal"

	return _make_terrain_motion_profile(
		motion_id,
		_get_layer_custom_float(layer, cell, CUSTOM_ACCELERATION_MULTIPLIER, _get_default_acceleration_multiplier(motion_id)),
		_get_layer_custom_float(layer, cell, CUSTOM_FRICTION_MULTIPLIER, _get_default_friction_multiplier(motion_id)),
		_get_layer_custom_float(layer, cell, CUSTOM_TURN_CONTROL_MULTIPLIER, _get_default_turn_control_multiplier(motion_id))
	)


func _get_default_motion_id_for_terrain(terrain_type: StringName) -> StringName:
	match terrain_type:
		&"ice", &"ice_ground", &"frozen_ground":
			return &"ice"
		_:
			return &""


func _get_default_acceleration_multiplier(motion_id: StringName) -> float:
	match motion_id:
		&"ice":
			return 0.18
		_:
			return 1.0


func _get_default_friction_multiplier(motion_id: StringName) -> float:
	match motion_id:
		&"ice":
			return 0.04
		_:
			return 1.0


func _get_default_turn_control_multiplier(motion_id: StringName) -> float:
	match motion_id:
		&"ice":
			return 0.24
		_:
			return 1.0


func _make_terrain_motion_profile(
	motion_id: StringName,
	acceleration_multiplier: float,
	friction_multiplier: float,
	turn_control_multiplier: float
) -> Dictionary:
	return {
		"motion_id": motion_id,
		"acceleration_multiplier": max(acceleration_multiplier, 0.0),
		"friction_multiplier": max(friction_multiplier, 0.0),
		"turn_control_multiplier": clamp(turn_control_multiplier, 0.0, 1.0),
	}


func _get_bounds_layers() -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	for layer: TileMapLayer in ground_layers:
		result.append(layer)
	if obstacle_layer != null:
		result.append(obstacle_layer)
	if effect_layer != null:
		result.append(effect_layer)
	return result


func _get_reference_layer() -> TileMapLayer:
	if not ground_layers.is_empty():
		return ground_layers[0]
	if obstacle_layer != null:
		return obstacle_layer
	if effect_layer != null:
		return effect_layer
	if decoration_layer != null:
		return decoration_layer
	if spawn_points_layer != null:
		return spawn_points_layer
	if object_spawn_layer != null:
		return object_spawn_layer
	return null


func _get_reference_cell_size() -> Vector2:
	var reference_layer: TileMapLayer = _get_reference_layer()
	if reference_layer != null and reference_layer.tile_set != null:
		return Vector2(reference_layer.tile_set.tile_size)
	return Vector2(16.0, 16.0)


func _resolve_navigation_cell(cell: Vector2i) -> Variant:
	if _is_navigation_cell_walkable(cell):
		return cell
	return _find_nearest_navigation_cell(cell, nearest_walkable_cell_search_radius)


func _is_navigation_cell_walkable(cell: Vector2i) -> bool:
	if navigation_grid == null:
		return false
	if not navigation_grid.is_in_boundsv(cell):
		return false
	return not navigation_grid.is_point_solid(cell)


func _find_nearest_navigation_cell(origin_cell: Vector2i, max_radius: int) -> Variant:
	var resolved_radius: int = max(max_radius, 0)
	for radius: int in range(0, resolved_radius + 1):
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if radius > 0 and abs(x_offset) < radius and abs(y_offset) < radius:
					continue

				var candidate: Vector2i = origin_cell + Vector2i(x_offset, y_offset)
				if _is_navigation_cell_walkable(candidate):
					return candidate

	return null


func _rect_has_cell(rect: Rect2i, cell: Vector2i) -> bool:
	return (
		cell.x >= rect.position.x
		and cell.y >= rect.position.y
		and cell.x < rect.position.x + rect.size.x
		and cell.y < rect.position.y + rect.size.y
	)
