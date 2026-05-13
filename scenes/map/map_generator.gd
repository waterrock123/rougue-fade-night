class_name MapGenerator
extends Node

const X_DIST := 320.0
const Y_DIST := 210.0
const PLACEMENT_RANDOMNESS := 18.0
const FLOORS := 6
const MIN_ROOMS_PER_FLOOR := 2
const MAX_ROOMS_PER_FLOOR := 4
const PATH_MAX_CONNECTIONS := 2

const EVENT_ROOM_WEIGHT := 5.0
const SHOP_ROOM_WEIGHT := 2.5
const CAMPFIRE_ROOM_WEIGHT := 4.0
const TREASURE_ROOM_WEIGHT := 3.0

const GENERIC_EVENT_SCENE := preload("res://event_room/event_room.tscn")
const CAMPFIRE_EVENT_SCENE := preload("res://event_room/campfire_room.tscn")
const TREASURE_EVENT_SCENE := preload("res://event_room/treasure_room.tscn")
const SHOP_EVENT_SCENE := preload("res://event_room/shop_chosen_room.tscn")

@export var battle_stats_pool: BattleStatsPool
@export var event_room_pool: EventRoomPool

var random_room_type_weights := {
	Room.Type.CAMPFIRE: 0.0,
	Room.Type.SHOP: 0.0,
	Room.Type.EVENT: 0.0,
	Room.Type.TREASURE: 0.0,
}
var random_room_type_total_weight := 0.0
var map_data: Array[Array] = []


func generate_map() -> Array[Array]:
	map_data = _generate_initial_grid()
	_connect_columns()

	if battle_stats_pool != null:
		battle_stats_pool.setup()

	_setup_random_room_weights()
	_setup_room_types()
	return map_data


func _generate_initial_grid() -> Array[Array]:
	var result: Array[Array] = []

	for floor_index in range(FLOORS):
		var rooms_in_floor: Array[Room] = []
		var vertical_slots := _get_random_vertical_slots()

		for slot_index in vertical_slots:
			var room := Room.new()
			var centered_y := (float(slot_index) - 1.5) * Y_DIST
			var offset := Vector2(
				RunRng.randf_range(-PLACEMENT_RANDOMNESS, PLACEMENT_RANDOMNESS),
				RunRng.randf_range(-PLACEMENT_RANDOMNESS, PLACEMENT_RANDOMNESS)
			)
			room.position = Vector2(floor_index * X_DIST, centered_y) + offset
			room.row = floor_index
			room.column = slot_index
			room.next_rooms = []
			rooms_in_floor.append(room)

		rooms_in_floor.sort_custom(func(a: Room, b: Room): return a.column < b.column)
		result.append(rooms_in_floor)

	return result


func _get_random_vertical_slots() -> Array[int]:
	var slot_pool := [0, 1, 2, 3]
	RunRng.shuffle_array(slot_pool)

	var room_count := RunRng.randi_range(MIN_ROOMS_PER_FLOOR, MAX_ROOMS_PER_FLOOR)
	var selected: Array[int] = []
	for slot_index in range(room_count):
		selected.append(int(slot_pool[slot_index]))
	selected.sort()
	return selected


func _connect_columns() -> void:
	for floor_index in range(FLOORS - 1):
		var current_floor: Array[Room] = map_data[floor_index]
		var next_floor: Array[Room] = map_data[floor_index + 1]

		for room in current_floor:
			var candidates := next_floor.duplicate()
			candidates.sort_custom(func(a: Room, b: Room): return abs(a.column - room.column) < abs(b.column - room.column))

			var connection_count = min(PATH_MAX_CONNECTIONS, candidates.size())
			if connection_count > 1 and RunRng.randf() < 0.45:
				connection_count = 2
			else:
				connection_count = 1

			for candidate_index in range(connection_count):
				var next_room = candidates[candidate_index]
				_try_add_non_crossing_connection(room, next_room, current_floor)

			# 如果候选边都因为防交叉被跳过，至少补一条最近的不交叉连线。
			if room.next_rooms.is_empty():
				_connect_to_nearest_non_crossing_room(room, candidates, current_floor)

		_ensure_each_room_has_parent(floor_index)


func _ensure_each_room_has_parent(floor_index: int) -> void:
	var current_floor: Array[Room] = map_data[floor_index]
	var next_floor: Array[Room] = map_data[floor_index + 1]

	for next_room in next_floor:
		if _room_has_parent(next_room):
			continue

		var parents := current_floor.duplicate()
		parents.sort_custom(func(a: Room, b: Room): return abs(a.column - next_room.column) < abs(b.column - next_room.column))
		for parent in parents:
			if _try_add_non_crossing_connection(parent, next_room, current_floor):
				break
		if not _room_has_parent(next_room):
			_replace_crossing_connections_and_add(parents[0], next_room, current_floor)


func _connect_to_nearest_non_crossing_room(room: Room, candidates: Array, current_floor: Array[Room]) -> void:
	for candidate in candidates:
		if _try_add_non_crossing_connection(room, candidate, current_floor):
			return


# 添加连线的唯一入口：先检查是否会和同一段列间已有连线交叉，再真正写入 next_rooms。
func _try_add_non_crossing_connection(from_room: Room, to_room: Room, current_floor: Array[Room]) -> bool:
	if from_room == null or to_room == null:
		return false
	if from_room.next_rooms.has(to_room):
		return true
	if _would_connection_cross(from_room, to_room, current_floor):
		return false

	from_room.next_rooms.append(to_room)
	return true


# 判断 from_room -> to_room 是否会造成“上方房间连到下方、下方房间连到上方”的交叉线。
func _would_connection_cross(from_room: Room, to_room: Room, current_floor: Array[Room]) -> bool:
	for other_from in current_floor:
		if other_from == null or other_from == from_room:
			continue

		for other_to in other_from.next_rooms:
			if other_to == null or other_to == to_room:
				continue
			if _is_crossing_connection(from_room, to_room, other_from, other_to):
				return true

	return false


# 极少数情况下，为了保证下一列房间至少有一个父节点，会移除冲突边后再补上必需连线。
func _replace_crossing_connections_and_add(from_room: Room, to_room: Room, current_floor: Array[Room]) -> void:
	if from_room == null or to_room == null:
		return

	for other_from in current_floor:
		if other_from == null or other_from == from_room:
			continue

		for index in range(other_from.next_rooms.size() - 1, -1, -1):
			var other_to := other_from.next_rooms[index]
			if other_to != null and _is_crossing_connection(from_room, to_room, other_from, other_to):
				other_from.next_rooms.remove_at(index)

	if not from_room.next_rooms.has(to_room):
		from_room.next_rooms.append(to_room)


func _is_crossing_connection(a_from: Room, a_to: Room, b_from: Room, b_to: Room) -> bool:
	var from_delta := a_from.column - b_from.column
	var to_delta := a_to.column - b_to.column
	return from_delta * to_delta < 0


func _room_has_parent(room: Room) -> bool:
	if room.row <= 0:
		return false

	for parent_room in map_data[room.row - 1]:
		if parent_room.next_rooms.has(room):
			return true

	return false


func _setup_random_room_weights() -> void:
	random_room_type_weights[Room.Type.CAMPFIRE] = CAMPFIRE_ROOM_WEIGHT
	random_room_type_weights[Room.Type.SHOP] = random_room_type_weights[Room.Type.CAMPFIRE] + SHOP_ROOM_WEIGHT
	random_room_type_weights[Room.Type.EVENT] = random_room_type_weights[Room.Type.SHOP] + EVENT_ROOM_WEIGHT
	random_room_type_weights[Room.Type.TREASURE] = random_room_type_weights[Room.Type.EVENT] + TREASURE_ROOM_WEIGHT
	random_room_type_total_weight = random_room_type_weights[Room.Type.TREASURE]


func _setup_room_types() -> void:
	for floor_index in range(FLOORS):
		for room in map_data[floor_index]:
			if floor_index == 0:
				room.type = Room.Type.EVENT
			elif floor_index == FLOORS - 1:
				room.type = Room.Type.BOSS
			else:
				room.type = _get_random_room_type_by_weight()

			room.battle_stats = _get_battle_for_room(room)
			room.event_scene = _get_event_scene_for_room(room)


func _get_battle_for_room(room: Room) -> BattleStats:
	if battle_stats_pool == null or room == null:
		return null

	var tier := 0
	if room.row >= 4:
		tier = 2
	elif room.row >= 2:
		tier = 1

	return battle_stats_pool.get_random_battle_for_tier(tier)


func _get_event_scene_for_room(room: Room) -> PackedScene:
	match room.type:
		Room.Type.CAMPFIRE:
			return CAMPFIRE_EVENT_SCENE
		Room.Type.TREASURE:
			return TREASURE_EVENT_SCENE
		Room.Type.SHOP:
			return SHOP_EVENT_SCENE
		Room.Type.EVENT:
			if event_room_pool != null:
				var random_event := event_room_pool.get_random()
				if random_event != null:
					return random_event

	return GENERIC_EVENT_SCENE


func _get_random_room_type_by_weight() -> Room.Type:
	var roll := RunRng.randf_range(0.0, random_room_type_total_weight)

	for type: Room.Type in random_room_type_weights:
		if random_room_type_weights[type] > roll:
			return type

	return Room.Type.EVENT
