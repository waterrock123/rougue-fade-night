class_name BasicTutorialRoom
extends TrainingRoom

static var pending_character: Character
const LESSONS: TutorialLessonCatalog = preload("res://custom_resource/basic_tutorial_lessons.tres")
const PANEL: PackedScene = preload("res://scenes/hub/basic_tutorial_panel.tscn")
const MARKER: PackedScene = preload("res://scenes/hub/tutorial_world_marker.tscn")
@export_file("*.tscn") var tutorial_map_path: String = "res://scenes/battlemap/templates/sample_03_中央竞技场.tscn"
var lesson: TutorialCharacterLesson
var tutorial_panel: BasicTutorialPanel
var tutorial_controller: BasicTutorialController
var movement_goal: Vector2


func _ready() -> void:
	if pending_character != null:
		selected_character = pending_character
		pending_character = null
	if selected_character == null:
		selected_character = load("res://character_resource/warrior/warrior.tres") as Character
	lesson = LESSONS.resolve(selected_character)
	enable_debug_console = false
	dummy_health = 1000000.0
	dummy_armor = 0
	infinite_health = true
	infinite_energy = true
	super._ready()


func _create_training_player_build(startup: RunStartup) -> PlayerBuild:
	return TutorialBuildFactory.create_build(startup, lesson)


func _create_training_controls() -> void:
	package_button.hide()
	debug_button.hide()
	pause_button.hide()
	tutorial_panel = PANEL.instantiate() as BasicTutorialPanel
	add_child(tutorial_panel)
	tutorial_panel.return_requested.connect(_return_to_hub)
	tutorial_panel.restart_requested.connect(restart_training)


func _configure_training_battle() -> void:
	# 固定可控场地，不进入正式路线，也不消耗地图模板抽取随机数。
	training_battle.use_battle_map_templates = true
	run_stats.current_battle_map_template_path = tutorial_map_path
	var fallback: Node = training_battle.get_node("BattleMap")
	for node: Node in fallback.find_children("*", "", true, false):
		if node is BattleMapGenerator:
			(node as BattleMapGenerator).auto_generate_on_ready = false
		elif node is ObjectSpawnerFromTileMap:
			(node as ObjectSpawnerFromTileMap).auto_spawn_on_ready = false
	var spawner: EnemySpawner = training_battle.get_node("EnemySpawner") as EnemySpawner
	spawner.enable_random_bounty_spawn = false


func _start_training_battle() -> void:
	super._start_training_battle()
	var marker: TutorialWorldMarker = MARKER.instantiate() as TutorialWorldMarker
	training_battle.add_child(marker)
	tutorial_controller = BasicTutorialController.new()
	tutorial_controller.player = training_battle.player
	tutorial_controller.dummy = dummy
	tutorial_controller.lesson = lesson
	tutorial_controller.panel = tutorial_panel
	tutorial_controller.marker = marker
	tutorial_controller.character_name = run_stats.picked_character.character_name
	tutorial_controller.movement_goal = movement_goal
	tutorial_controller.tutorial_completed.connect(_on_tutorial_completed)
	add_child(tutorial_controller)


func _choose_dummy_spawn_position() -> void:
	var origin: Vector2 = training_battle.player.global_position
	movement_goal = _find_practice_position(origin, Vector2(-96, 0))
	dummy_spawn_position = _find_practice_position(movement_goal, Vector2(96, 0))


func _find_practice_position(origin: Vector2, offset: Vector2) -> Vector2:
	var map: BattleMap = training_battle.battle_map
	for rotation: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var desired: Vector2 = origin + offset.rotated(rotation)
		var safe: Variant = map.get_nearest_playable_position(desired, 4, 1)
		if safe is Vector2 and origin.distance_to(safe) >= 48.0:
			return safe
	return origin


func _on_tutorial_completed() -> void:
	if not ProfileManager.record_basic_tutorial_completion(run_stats.picked_character.id):
		tutorial_panel.set_progress("教学已完成，但进度写入失败；本次练习仍可正常退出。")


func _on_dummy_died(_entity: Entity) -> void:
	# 万一测试构筑把假人秒杀，下一帧重开本章，不留下已释放的目标引用。
	call_deferred("restart_training")


func _exit_tree() -> void:
	EventBus.is_battle_active = false
	super._exit_tree()
