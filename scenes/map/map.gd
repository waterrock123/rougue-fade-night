class_name Map
extends Node2D

signal room_selected(room: Room)

const SCROLL_SPEED := 120.0
const DRAG_BUTTON := MOUSE_BUTTON_MIDDLE
const MAP_ROOM = preload("res://scenes/map/map_room.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D
@onready var map_background: CanvasLayer = $MapBackground


var map_data: Array[Array] = []
var floors_climbed: int = 0
var last_room: Room
var camera_min_x: float = 0.0
var camera_max_x: float = 0.0
var is_dragging_map: bool = false


func _ready() -> void:
	hide_map()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not camera_2d.enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == DRAG_BUTTON:
			is_dragging_map = mouse_event.pressed
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_move_camera(-SCROLL_SPEED)
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_move_camera(SCROLL_SPEED)
			return

	if event is InputEventMouseMotion and is_dragging_map:
		var motion_event := event as InputEventMouseMotion
		_move_camera(-motion_event.relative.x)


func generate_new_map() -> void:
	floors_climbed = 0
	last_room = null
	map_data = map_generator.generate_map()
	create_map()
	unlock_floor(0)


# 读档时用保存下来的房间数据重建地图，而不是重新随机生成。
func load_from_save_data(save_data: Dictionary) -> void:
	if save_data.is_empty():
		generate_new_map()
		return

	floors_climbed = int(save_data.get("floors_climbed", 0))
	map_data = _deserialize_map_data(save_data.get("floors", []))
	last_room = _find_room_by_key(save_data.get("last_room", {}) as Dictionary)
	create_map()

	if last_room == null:
		unlock_floor(floors_climbed)
	else:
		unlock_next_rooms()


# 保存地图的结构、已选房间和当前进度；PackedScene/Resource 用路径保存。
func get_save_data() -> Dictionary:
	return {
		"floors_climbed": floors_climbed,
		"last_room": _serialize_room_key(last_room),
		"floors": _serialize_map_data(),
	}


func create_map() -> void:
	_clear_visuals()

	for current_floor in map_data:
		for room in current_floor:
			_spawn_room(room)

	_center_map_visuals()


func unlock_floor(which_floor: int = floors_climbed) -> void:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room.row == which_floor:
			map_room.available = true


func unlock_next_rooms() -> void:
	if last_room == null:
		unlock_floor(0)
		return

	for map_room: MapRoom in rooms.get_children():
		if last_room.next_rooms.has(map_room.room):
			map_room.available = true


func show_map() -> void:
	show()
	map_background.visible = true
	camera_2d.enabled = true


func hide_map() -> void:
	hide()
	map_background.visible = false
	camera_2d.enabled = false
	is_dragging_map = false


func _spawn_room(room: Room) -> void:
	var new_map_room := MAP_ROOM.instantiate() as MapRoom
	rooms.add_child(new_map_room)
	new_map_room.room = room
	new_map_room.clicked.connect(_on_map_room_clicked)
	new_map_room.selected.connect(_on_map_room_selected)
	_connect_lines(room)

	if room.selected and room.row < floors_climbed:
		new_map_room.show_selected()


func _connect_lines(room: Room) -> void:
	if room.next_rooms.is_empty():
		return

	for next_room in room.next_rooms:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(room.position)
		new_map_line.add_point(next_room.position)
		lines.add_child(new_map_line)


func _on_map_room_clicked(room: Room) -> void:
	for map_room: MapRoom in rooms.get_children():
		if map_room.room.row == room.row:
			map_room.available = false


func _on_map_room_selected(room: Room) -> void:
	last_room = room
	floors_climbed = max(floors_climbed, room.row + 1)
	room_selected.emit(room)
	print("有发出信号")


func _clear_visuals() -> void:
	for child in rooms.get_children():
		child.queue_free()

	for child in lines.get_children():
		child.queue_free()


func _center_map_visuals() -> void:
	var viewport_size := get_viewport_rect().size
	visuals.position = Vector2(220.0, viewport_size.y * 0.5)

	var total_width :float = max((MapGenerator.FLOORS - 1) * MapGenerator.X_DIST, 0.0)
	var left_bound := viewport_size.x * 0.5
	var right_bound :float = max(left_bound, visuals.position.x + total_width - viewport_size.x * 0.5 + 220.0)

	camera_min_x = left_bound
	camera_max_x = right_bound
	camera_2d.position = Vector2(camera_min_x, viewport_size.y * 0.5)


func _move_camera(delta_x: float) -> void:
	camera_2d.position.x = clamp(camera_2d.position.x + delta_x, camera_min_x, camera_max_x)


func _serialize_map_data() -> Array:
	var result := []
	for floor in map_data:
		var floor_data := []
		for room: Room in floor:
			floor_data.append({
				"type": int(room.type),
				"row": room.row,
				"column": room.column,
				"position_x": room.position.x,
				"position_y": room.position.y,
				"selected": room.selected,
				"battle_stats_path": room.battle_stats.resource_path if room.battle_stats != null else "",
				"event_scene_path": room.event_scene.resource_path if room.event_scene != null else "",
				"next_rooms": _serialize_next_room_keys(room),
			})
		result.append(floor_data)
	return result


func _deserialize_map_data(saved_floors) -> Array[Array]:
	var result: Array[Array] = []
	var room_lookup := {}
	if not (saved_floors is Array):
		return result

	for floor_data in saved_floors:
		var floor_rooms: Array[Room] = []
		if not (floor_data is Array):
			result.append(floor_rooms)
			continue

		for room_data in floor_data:
			var data := room_data as Dictionary
			var room := Room.new()
			room.type = int(data.get("type", Room.Type.EVENT))
			room.row = int(data.get("row", 0))
			room.column = int(data.get("column", 0))
			room.position = Vector2(float(data.get("position_x", 0.0)), float(data.get("position_y", 0.0)))
			room.selected = bool(data.get("selected", false))
			room.battle_stats = _load_resource_or_null(str(data.get("battle_stats_path", ""))) as BattleStats
			room.event_scene = _load_resource_or_null(str(data.get("event_scene_path", ""))) as PackedScene
			room.next_rooms = []
			floor_rooms.append(room)
			room_lookup[_room_lookup_key(room.row, room.column)] = room

		result.append(floor_rooms)

	_restore_room_connections(saved_floors, room_lookup)
	return result


func _restore_room_connections(saved_floors: Array, room_lookup: Dictionary) -> void:
	for floor_data in saved_floors:
		if not (floor_data is Array):
			continue

		for room_data in floor_data:
			var data := room_data as Dictionary
			var room := room_lookup.get(_room_lookup_key(int(data.get("row", 0)), int(data.get("column", 0)))) as Room
			if room == null:
				continue

			for next_room_data in data.get("next_rooms", []):
				var next_key := next_room_data as Dictionary
				var next_room := room_lookup.get(_room_lookup_key(int(next_key.get("row", 0)), int(next_key.get("column", 0)))) as Room
				if next_room != null:
					room.next_rooms.append(next_room)


func _serialize_next_room_keys(room: Room) -> Array:
	var result := []
	if room == null:
		return result

	for next_room in room.next_rooms:
		result.append(_serialize_room_key(next_room))
	return result


func _serialize_room_key(room: Room) -> Dictionary:
	if room == null:
		return {}

	return {
		"row": room.row,
		"column": room.column,
	}


func _find_room_by_key(data: Dictionary) -> Room:
	if data.is_empty():
		return null

	var row := int(data.get("row", -1))
	var column := int(data.get("column", -1))
	for floor in map_data:
		for room: Room in floor:
			if room.row == row and room.column == column:
				return room
	return null


func _room_lookup_key(row: int, column: int) -> String:
	return "%s:%s" % [row, column]


func _load_resource_or_null(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
