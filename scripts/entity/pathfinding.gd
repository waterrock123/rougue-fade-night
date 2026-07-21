class_name Pathfinding
extends Node2D

@export_group("避让")
@export var neigbour_check_radius: float = 30.0
@export var separation_force: float = 300.0

@export_group("地图寻路")
## 开启后会优先向 BattleMap 请求 AStarGrid2D 路径；请求失败时退回直线追击。
@export var use_battle_map_navigation: bool = true
## 已经足够接近路径点时，会直接取下一个路径点，避免原地抖动。
@export var path_point_arrive_distance: float = 10.0

@export_group("卡住恢复")
## 开启后，如果一段时间内想移动但几乎没有位移，会临时向侧面偏转脱困。
@export var stuck_detection_enabled: bool = true
@export var stuck_check_interval: float = 0.35
@export var stuck_min_progress: float = 3.0
@export var stuck_recovery_duration: float = 0.65
@export var stuck_steer_angle_degrees: float = 65.0
## 卡住恢复期间降低分离力，避免敌人之间的推挤把自己继续顶在墙角。
@export_range(0.0, 1.0, 0.05) var stuck_separation_multiplier: float = 0.35

var battle_map_cache: BattleMap
var stuck_check_timer: float = 0.0
var stuck_recovery_timer: float = 0.0
var stuck_side_sign: int = 1
var last_progress_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	last_progress_position = _get_owner_position()


func find_path(target_pos: Vector2) -> Vector2:
	var base_vector: Vector2 = _get_navigation_vector(target_pos)
	_update_stuck_state(base_vector)
	base_vector = _apply_stuck_recovery(base_vector)

	var separation_vector: Vector2 = separation(_collect_neighbours())
	var separation_scale: float = stuck_separation_multiplier if stuck_recovery_timer > 0.0 else 1.0
	return base_vector + separation_vector * separation_force * separation_scale


func _get_navigation_vector(target_pos: Vector2) -> Vector2:
	if use_battle_map_navigation:
		var battle_map: BattleMap = _get_battle_map()
		if battle_map != null:
			var next_point_value: Variant = battle_map.get_next_navigation_point(global_position, target_pos, path_point_arrive_distance)
			if next_point_value is Vector2:
				return next_point_value - global_position

	return target_pos - global_position


func _collect_neighbours() -> Array[Enemy]:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = neigbour_check_radius
	
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.transform.origin = self.global_position
	
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	
	var neigbours: Array[Enemy] = []
	for result: Dictionary in results:
		var collider: Object = result.get("collider")
		if not (collider is Node):
			continue

		var parent: Node = (collider as Node).get_parent()
		if parent is Enemy and parent != self.get_parent():
			neigbours.push_back(parent)

	return neigbours


func separation(neigbours: Array[Enemy]) -> Vector2:
	var seperation_vector: Vector2 = Vector2.ZERO
	for neigbour: Enemy in neigbours:
		var to_me: Vector2 = self.global_position - neigbour.global_position
		var distance: float = to_me.length()
	
		if distance > 0.0:
			seperation_vector += to_me.normalized() / distance
			
	
	return seperation_vector


func _update_stuck_state(desired_vector: Vector2) -> void:
	if not stuck_detection_enabled:
		return

	var delta: float = get_process_delta_time()
	stuck_recovery_timer = max(stuck_recovery_timer - delta, 0.0)
	if desired_vector.length_squared() <= 1.0:
		last_progress_position = _get_owner_position()
		stuck_check_timer = stuck_check_interval
		return

	stuck_check_timer -= delta
	if stuck_check_timer > 0.0:
		return

	var current_position: Vector2 = _get_owner_position()
	var progress: float = current_position.distance_to(last_progress_position)
	last_progress_position = current_position
	stuck_check_timer = max(stuck_check_interval, 0.05)

	if progress >= stuck_min_progress:
		return

	# 连续想走却几乎没动，说明可能卡在墙角或队友身上；切换偏转方向尝试脱困。
	stuck_side_sign *= -1
	stuck_recovery_timer = max(stuck_recovery_duration, 0.0)


func _apply_stuck_recovery(base_vector: Vector2) -> Vector2:
	if stuck_recovery_timer <= 0.0:
		return base_vector
	if base_vector == Vector2.ZERO:
		return base_vector

	var angle: float = deg_to_rad(stuck_steer_angle_degrees) * float(stuck_side_sign)
	return base_vector.rotated(angle)


func _get_owner_position() -> Vector2:
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node == null:
		return global_position
	return owner_node.global_position


func _get_battle_map() -> BattleMap:
	if battle_map_cache != null and is_instance_valid(battle_map_cache):
		return battle_map_cache

	var maps: Array = get_tree().get_nodes_in_group("battle_map")
	for node in maps:
		if node is BattleMap:
			battle_map_cache = node
			return battle_map_cache

	return null
