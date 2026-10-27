class_name TrainingRoom
extends Run

## 独立训练容器：复用 Run UI 接口，但不调用正式开局、存档或剧情结算。
static var selected_character: Character
@export var dummy_health: float = 1000.0
@export var dummy_armor: int = 0
@export var dummy_poise: float = 10.0
var training_battle: PlayScene
var infinite_health: bool = true
var infinite_energy: bool = true
var no_cooldown: bool = false
var saved_rng: Dictionary
var controls: HBoxContainer
var dummy: Enemy
var dummy_spawn_position: Vector2


func _ready() -> void:
	process_priority = -100
	saved_rng = RunRng.get_save_data()
	var startup: RunStartup = RunStartup.new()
	startup.picked_character = selected_character
	if startup.picked_character == null:
		startup.picked_character = load("res://character_resource/warrior/warrior.tres") as Character
	run_stats = RunStats.new()
	run_stats.setup_new_run(_create_training_player_build(startup), startup.create_shop(), startup.create_shop_config(), startup.picked_character)
	_initialize_runtime_proxy()
	_initialize_persistent_ui()
	map.hide_map()
	map_tag_button.hide()
	pause_button.text = "返回大厅"
	pause_button.pressed.connect(_return_to_hub)
	if not package_button.pressed.is_connected(_on_package_button_pressed):
		package_button.pressed.connect(_on_package_button_pressed)
	debug_button.pressed.connect(_on_debug_button_pressed)
	debug_console.opened.connect(_on_debug_console_opened)
	debug_console.closed.connect(_on_debug_console_closed)
	_create_training_controls()
	_start_training_battle()


## 教学可以定制临时构筑；普通训练场仍完整使用角色的起始构筑。
func _create_training_player_build(startup: RunStartup) -> PlayerBuild:
	return startup.create_player_build()


func _configure_training_battle() -> void:
	pass


func _start_training_battle() -> void:
	training_battle = (load(PLAY_SCENE_PATH) as PackedScene).instantiate() as PlayScene
	training_battle.set_script(load("res://scripts/hub/training_battle.gd"))
	training_battle.use_battle_map_templates = false
	training_battle.validate_battle_map_generation = false
	training_battle.setup_run_battle(run_stats, null)
	_configure_training_battle()
	current_view.add_child(training_battle)
	_choose_dummy_spawn_position()
	_spawn_dummy()
	_set_package_equipment_locked(false)
	_refresh_persistent_ui()


## 复用已有地图的可行走位置，避免假人被放进墙里。
func _spawn_dummy() -> void:
	if not is_instance_valid(training_battle) or is_instance_valid(dummy):
		return
	dummy = (load("res://scenes/hub/training_dummy.tscn") as PackedScene).instantiate() as Enemy
	var stats: StatsData = StatsData.new()
	stats.base_max_health = dummy_health
	stats.base_static_damage_reduction = dummy_armor
	(dummy.get_node("StatsController") as StatsController).stats_data = stats
	dummy.max_poise = dummy_poise
	training_battle.add_child(dummy)
	dummy.global_position = dummy_spawn_position
	dummy.died.connect(_on_dummy_died)


## 进入训练场时只选一次驻点，复活和手动重置均使用该位置。
func _choose_dummy_spawn_position() -> void:
	var origin: Vector2 = training_battle.player.global_position
	dummy_spawn_position = origin
	for offset: Vector2 in [Vector2(100, 0), Vector2(-100, 0), Vector2(0, 100), Vector2(0, -100)]:
		if training_battle.battle_map.is_world_position_walkable(origin + offset):
			dummy_spawn_position = origin + offset
			break


func _on_dummy_died(_entity: Entity) -> void:
	dummy = null
	get_tree().create_timer(1.0).timeout.connect(_spawn_dummy)


## 开关只改变训练实例，关闭后立即恢复常规消耗和冷却。
func _process(_delta: float) -> void:
	if not is_instance_valid(training_battle) or not is_instance_valid(training_battle.player):
		return
	var player: Player = training_battle.player
	if infinite_health:
		player.grant_invulnerability(0.1)
	if infinite_energy:
		player.current_energy = player.max_energy
		player.stats_controller.current_energy = player.max_energy
		EventBus.player_energy_changed.emit(player.current_energy, player.max_energy)


func _create_training_controls() -> void:
	controls = HBoxContainer.new()
	controls.position = Vector2(24, 115)
	controls.add_theme_constant_override("separation", 18)
	top_bar.add_child(controls)
	_add_switch("无限生命", true, func(value: bool) -> void: infinite_health = value)
	_add_switch("无限能量", true, func(value: bool) -> void: infinite_energy = value)
	_add_switch("无冷却（0.1秒）", false, _set_training_cooldown)
	var reset: Button = Button.new()
	reset.text = "重置训练"
	reset.pressed.connect(restart_training)
	controls.add_child(reset)
	var settings: HBoxContainer = HBoxContainer.new()
	settings.position = Vector2(24, 165)
	top_bar.add_child(settings)
	_add_number(settings, "假人生命", dummy_health, 1, 1000000, func(value: float) -> void: dummy_health = value)
	_add_number(settings, "固定减伤", dummy_armor, 0, 10000, func(value: float) -> void: dummy_armor = int(value))
	_add_number(settings, "韧性", dummy_poise, 1, 10000, func(value: float) -> void: dummy_poise = value)
	var apply_button: Button = Button.new()
	apply_button.text = "应用并重置假人"
	apply_button.pressed.connect(_reset_dummy)
	settings.add_child(apply_button)


func _add_number(row: HBoxContainer, caption: String, value: float, minimum: float, maximum: float, callback: Callable) -> void:
	var label: Label = Label.new()
	label.text = caption
	row.add_child(label)
	var field: SpinBox = SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.value = value
	field.value_changed.connect(callback)
	row.add_child(field)


func _reset_dummy() -> void:
	if is_instance_valid(dummy):
		dummy.get_parent().remove_child(dummy)
		dummy.queue_free()
	dummy = null
	_spawn_dummy()


func _add_switch(label: String, initial: bool, callback: Callable) -> void:
	var button: CheckButton = CheckButton.new()
	button.text = label
	button.button_pressed = initial
	button.toggled.connect(callback)
	controls.add_child(button)


## 只在切换时缩短已有计时，新施法由控制器设置真实的 0.1 秒冷却。
func _set_training_cooldown(enabled: bool) -> void:
	no_cooldown = enabled
	var controller: AbilityController = training_battle.player.ability_controller
	controller.training_cooldown_override = 0.1 if enabled else -1.0
	if enabled:
		for ability: Ability in controller.abilities:
			var remaining: float = minf(float(controller.cooldowns.get(ability, 0.0)), 0.1)
			controller.cooldowns[ability] = remaining
			ability.current_cooldown = remaining


func restart_training() -> void:
	_cancel_training_actions()
	selected_character = run_stats.picked_character
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not debug_console.visible:
		get_viewport().set_input_as_handled()
		_return_to_hub()


func _return_to_hub() -> void:
	_cancel_training_actions()
	debug_console.close_panel()
	_close_persistent_panels()
	selected_character = run_stats.picked_character
	ResourceLocator.go_to_hub_scene(false)


## 切场景前使所有行动上下文失效，避免旧冲刺继续更新位移。
func _cancel_training_actions() -> void:
	if is_instance_valid(training_battle):
		for node: Node in training_battle.find_children("*", "", true, false):
			if node is Entity:
				(node as Entity).cancel_active_actions()


## 所有继承的 UI 保存请求都在此截断，训练绝不覆盖正式继续存档。
func can_debug_battle_map_override() -> bool:
	return false


func _save_current_run(_force: bool = false) -> void:
	pass


func _exit_tree() -> void:
	RunRng.restore_from_save(int(saved_rng.get("seed", 0)), int(saved_rng.get("state", 0)))
