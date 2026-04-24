class_name Run
extends Node

const PLAY_SCENE_PATH := "res://scenes/play_scene.tscn"
const REST_SCENE_PATH := "res://scenes/rest_period/rest_period.tscn"

static var pending_startup: RunStartup

@export var run_startup: RunStartup

@onready var current_view: Node = $CurrentView
@onready var map: Map = $Map

var run_stats: RunStats
var current_room: Room


func _ready() -> void:
	_connect_signals()
	_initialize_run_state()
	_initialize_map()


func change_to_play_scene() -> void:
	if current_room == null:
		return

	_open_battle_scene(current_room)


func change_to_rest_period() -> void:
	var rest_scene_resource := load(REST_SCENE_PATH) as PackedScene
	if rest_scene_resource == null:
		return

	var rest_scene := rest_scene_resource.instantiate()
	_bind_run_stats(rest_scene)
	_replace_current_view(rest_scene)
	map.hide_map()


func finish_rest_period() -> void:
	_clear_current_view()
	map.show_map()
	map.unlock_next_rooms()


func _connect_signals() -> void:
	if map != null and not map.room_selected.is_connected(_on_map_room_selected):
		map.room_selected.connect(_on_map_room_selected)

	if not EventBus.event_room_exited.is_connected(_on_event_room_exited):
		EventBus.event_room_exited.connect(_on_event_room_exited)


func _initialize_run_state() -> void:
	if run_stats != null:
		return

	var startup := _resolve_startup()
	if startup == null or startup.picked_character == null:
		return

	run_stats = RunStats.new()
	run_stats.gold = RunStats.STARTING_GOLD
	run_stats.player_build = _create_player_build_from_character(startup.picked_character)


func _initialize_map() -> void:
	if map == null:
		return

	map.generate_new_map()
	map.show_map()


func _resolve_startup() -> RunStartup:
	if pending_startup != null:
		var startup := pending_startup
		pending_startup = null
		return startup

	return run_startup


func _create_player_build_from_character(character: Character) -> PlayerBuild:
	var build := PlayerBuild.new()
	build.player_stats = _duplicate_resource(character.start_stats)
	build.player_inventory = _duplicate_resource(character.start_inventory)
	build.player_equipment = _duplicate_resource(character.start_equipment)
	build.current_health = 0.0
	build.current_energy = 0.0
	return build


func _duplicate_resource(resource: Resource):
	if resource == null:
		return null
	return resource.duplicate(true)


func _on_map_room_selected(room: Room) -> void:
	print("有收信号")
	current_room = room
	_open_event_room(room)


func _on_event_room_exited() -> void:
	if current_room == null:
		return

	_open_battle_scene(current_room)


func _open_event_room(room: Room) -> void:
	if room == null or room.event_scene == null:
		return

	var event_room := room.event_scene.instantiate()
	_bind_run_stats(event_room)
	_replace_current_view(event_room)
	map.hide_map()

	if event_room.has_method("setup"):
		event_room.setup()


func _open_battle_scene(room: Room) -> void:
	if room == null:
		return

	var play_scene_resource := load(PLAY_SCENE_PATH) as PackedScene
	if play_scene_resource == null:
		return

	var play_scene := play_scene_resource.instantiate()
	if play_scene == null:
		return

	if play_scene.has_method("setup_run_battle"):
		play_scene.setup_run_battle(run_stats, room.battle_stats)
	else:
		_bind_run_stats(play_scene)

	_replace_current_view(play_scene)
	map.hide_map()


func _replace_current_view(scene: Node) -> void:
	_clear_current_view()
	current_view.add_child(scene)


func _clear_current_view() -> void:
	var current_scene := _get_current_scene()
	if current_scene == null:
		return

	current_view.remove_child(current_scene)
	current_scene.queue_free()


func _bind_run_stats(scene: Node) -> void:
	if scene == null:
		return

	if "run_stats" in scene:
		scene.run_stats = run_stats


func _get_current_scene() -> Node:
	if current_view.get_child_count() == 0:
		return null

	return current_view.get_child(0)
