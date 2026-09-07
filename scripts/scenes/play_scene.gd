class_name PlayScene
extends Node2D

const REST_PERIOD_SCENE := preload("res://scenes/rest_period/rest_period.tscn")
const STATUS_UI_SCENE := preload("res://scenes/ui/status_ui.tscn")
const TAG_EFFECT_DATABASE := preload("res://custom_resource/default_tag_effect_database.tres")
const BATTLE_MESSAGE_LOG_SCENE := preload("res://scenes/ui/battle_message_log.tscn")
@export var screen_transition: ColorRect
@export var player_health_bar: PlayerHealthBar
@export var run_stats: RunStats
## 临时开关：如果某张地图模板导致 Godot 编辑器崩溃，可先关掉模板替换，退回场景内默认 BattleMap。
@export var use_battle_map_templates: bool = true
## 战斗地图模板路径。这里故意存路径而不是 PackedScene，避免编辑器打开项目时一次性递归加载所有模板。
@export var battle_map_template_paths: PackedStringArray = PackedStringArray([
	"res://scenes/battlemap/templates/grass_open_01.tscn",
	"res://scenes/battlemap/templates/grass_corridor_01.tscn",
	"res://scenes/battlemap/templates/grass_center_wall_01.tscn",
])
@export_group("地图生成验证")
## 地图物体和特殊地形生成后，是否检查出生点和可达区域。
@export var validate_battle_map_generation: bool = true
## 可达区域低于此比例时输出警告。狭窄走廊地图可以适当降低这个值。
@export_range(0.0, 1.0, 0.05) var map_validation_min_reachable_ratio: float = 0.9
## 是否在输出面板打印地图验证结果。
@export var log_battle_map_validation: bool = true

var player: Player
var pending_battle_stats: BattleStats
var bound_status_controller: StatusController
var consumable_preview_indicator: AbilityAreaIndicator
var previewing_consumable_effect: UseSpawnManifestEffect
var previewing_consumable_slot_index: int = -1
var tag_effect_controller: TagEffectController
var bounty_hint_label: Label
var battle_message_log: BattleMessageLog
var has_active_bounty_hint: bool = false
var terrain_effect_controller: TerrainEffectController
var terrain_randomizer: BattleMapTerrainRandomizer
var object_spawner: ObjectSpawnerFromTileMap
var battle_map_generation_validator: BattleMapGenerationValidator
var detached_fallback_battle_map: BattleMap
var battle_completion_started: bool = false

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var battle_map: BattleMap = $BattleMap
@onready var spell_bar: SpellBar = $CanvasLayer/UI/SpellBar
@onready var passive_skill_bar: PassiveSkillBar = $CanvasLayer/UI/PassiveSkillBar
@onready var consumable_container: ConsumableContainer = $CanvasLayer/UI/ConsumableContainer
@onready var status_container: GridContainer = $CanvasLayer/UI/StatusContainer

var consumable_use_count := 0


func _ready() -> void:
	EventBus.is_battle_active = false
	player = get_tree().get_first_node_in_group("player") as Player
	_setup_battle_message_log()
	_initialize_battle_map_template()
	_configure_world_depth_sorting()
	if run_stats != null and run_stats.player_build != null and player != null:
		player.bind_player_build(run_stats.player_build, run_stats.picked_character)
	_initialize_battle_map()
	if run_stats != null and run_stats.player_build != null and player != null:
		_initialize_battle_tag_effect_controller()

	_refresh_skill_ui()
	_refresh_consumable_ui()
	_bind_player_status_ui()

	if enemy_spawner != null and pending_battle_stats != null:
		enemy_spawner.battle_stats = pending_battle_stats

	if player != null and not player.player_died.is_connected(_handle_game_over):
		player.player_died.connect(_handle_game_over)
	if enemy_spawner != null and not enemy_spawner.battle_completed.is_connected(_on_enemy_spawner_battle_completed):
		enemy_spawner.battle_completed.connect(_on_enemy_spawner_battle_completed)
	if not EventBus.battle_end_requested.is_connected(_handle_battle_end_requested):
		EventBus.battle_end_requested.connect(_handle_battle_end_requested)
	if enemy_spawner != null and not enemy_spawner.bounty_enemy_presence_changed.is_connected(_handle_bounty_enemy_presence_changed):
		enemy_spawner.bounty_enemy_presence_changed.connect(_handle_bounty_enemy_presence_changed)
	_setup_bounty_hint_ui()
	_spawn_pending_bounty_enemies()
	_handle_bounty_enemy_presence_changed(enemy_spawner.has_active_bounty_enemies() if enemy_spawner != null else false)

	AudioController.play_bg_music("battle")
	if not EventBus.game_paused.is_connected(_handle_pause):
		EventBus.game_paused.connect(_handle_pause)
	if not EventBus.equipment_update.is_connected(_refresh_consumable_ui):
		EventBus.equipment_update.connect(_refresh_consumable_ui)
	if not EventBus.bounty_enemy_killed.is_connected(_handle_bounty_enemy_killed):
		EventBus.bounty_enemy_killed.connect(_handle_bounty_enemy_killed)

	# 所有玩家构筑、装备效果和 UI 都初始化后，再通知“进场触发”效果结算。
	EventBus.is_battle_active = true
	EventBus.battle_started.emit()


func _exit_tree() -> void:
	EventBus.is_battle_active = false
	if EventBus.game_paused.is_connected(_handle_pause):
		EventBus.game_paused.disconnect(_handle_pause)
	if EventBus.equipment_update.is_connected(_refresh_consumable_ui):
		EventBus.equipment_update.disconnect(_refresh_consumable_ui)
	if EventBus.bounty_enemy_killed.is_connected(_handle_bounty_enemy_killed):
		EventBus.bounty_enemy_killed.disconnect(_handle_bounty_enemy_killed)
	if EventBus.battle_end_requested.is_connected(_handle_battle_end_requested):
		EventBus.battle_end_requested.disconnect(_handle_battle_end_requested)
	if enemy_spawner != null and enemy_spawner.bounty_enemy_presence_changed.is_connected(_handle_bounty_enemy_presence_changed):
		enemy_spawner.bounty_enemy_presence_changed.disconnect(_handle_bounty_enemy_presence_changed)
	_unbind_player_status_ui()
	_cleanup_battle_tag_effect_controller()
	_cancel_consumable_preview()
	if detached_fallback_battle_map != null and is_instance_valid(detached_fallback_battle_map):
		detached_fallback_battle_map.queue_free()
	detached_fallback_battle_map = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_consumable"):
		_begin_or_use_equipped_consumable()
	elif event.is_action_released("use_consumable"):
		_release_equipped_consumable_preview()


func setup_run_battle(new_run_stats: RunStats, battle_stats: BattleStats) -> void:
	run_stats = new_run_stats
	pending_battle_stats = battle_stats

	var scene_player := get_node_or_null("Player") as Player
	if scene_player != null and run_stats != null and run_stats.player_build != null:
		scene_player.stats_data = run_stats.player_build.player_stats
		scene_player.player_inventory = run_stats.player_build.player_inventory
		scene_player.player_equipment = run_stats.player_build.player_equipment

	var spawner := get_node_or_null("EnemySpawner") as EnemySpawner
	if spawner != null:
		spawner.battle_stats = battle_stats
		spawner.battle_map = get_node_or_null("BattleMap") as BattleMap


## 创建战斗左侧消息栏。
## 地图物体、拾取物、悬赏精英怪等“战斗内提示”都会被 FloatText 转发到这里。
func _setup_battle_message_log() -> void:
	if battle_message_log != null and is_instance_valid(battle_message_log):
		return

	var ui_root: Control = get_node_or_null("CanvasLayer/UI") as Control
	if ui_root == null:
		return

	battle_message_log = BATTLE_MESSAGE_LOG_SCENE.instantiate() as BattleMessageLog
	if battle_message_log == null:
		return

	ui_root.add_child(battle_message_log)
	battle_message_log.anchor_left = 0.0
	battle_message_log.anchor_right = 0.0
	battle_message_log.anchor_top = 0.5
	battle_message_log.anchor_bottom = 0.5
	battle_message_log.offset_left = 22.0
	battle_message_log.offset_right = 352.0
	battle_message_log.offset_top = -160.0
	battle_message_log.offset_bottom = 160.0


## 从模板池选择一张 BattleMap 模板，替换场景里默认的兜底 BattleMap。
## 模板选择放在战斗初始化最前面，这样玩家出生点、敌人刷怪点、地图物件都会读取新地图。
func _initialize_battle_map_template() -> void:
	if not use_battle_map_templates:
		return

	var template_path: String = _resolve_battle_map_template_path()
	if template_path.is_empty():
		return

	var template_scene: PackedScene = ResourceLoader.load(template_path) as PackedScene
	if template_scene == null:
		return

	var template_instance: BattleMap = template_scene.instantiate() as BattleMap
	if template_instance == null:
		push_warning("PlayScene 选中的战斗地图模板根节点不是 BattleMap：%s" % template_scene.resource_path)
		return

	_prepare_battle_map_template_instance(template_instance)
	_replace_battle_map(template_instance)


func _resolve_battle_map_template_path() -> String:
	# 存档中有模板路径时直接复用，只有新战斗才从本局随机数中抽取。
	if run_stats != null:
		var saved_path: String = run_stats.current_battle_map_template_path.strip_edges()
		if not saved_path.is_empty():
			if ResourceLoader.exists(saved_path):
				return saved_path
			push_warning("存档中的战斗地图模板不存在，将重新抽取地图：%s" % saved_path)
			run_stats.clear_battle_map_template()

	var valid_paths: Array[String] = _get_valid_battle_map_template_paths()
	if valid_paths.is_empty():
		return ""

	var picked_path: Variant = RunRng.pick(valid_paths)
	var template_path: String = str(picked_path)
	if template_path.is_empty():
		return ""

	if run_stats != null:
		run_stats.current_battle_map_template_path = template_path
	return template_path


func _get_valid_battle_map_template_paths() -> Array[String]:
	var result: Array[String] = []
	for template_path: String in battle_map_template_paths:
		var clean_path: String = template_path.strip_edges()
		if clean_path.is_empty():
			continue
		if not ResourceLoader.exists(clean_path):
			push_warning("PlayScene 找不到战斗地图模板：%s" % clean_path)
			continue
		result.append(clean_path)
	return result


func _prepare_battle_map_template_instance(template_instance: BattleMap) -> void:
	template_instance.name = "BattleMap"

	# 模板地图是手工设计的，进入战斗时不要再被旧的随机生成器覆盖。
	var generator: BattleMapGenerator = template_instance.get_node_or_null("BattleMapGenerator") as BattleMapGenerator
	if generator != null:
		generator.auto_generate_on_ready = false

	# 地图物件必须由 PlayScene 绑定 run_stats 后统一生成，避免自动生成时拿不到本局标签配置。
	var map_object_spawner: ObjectSpawnerFromTileMap = template_instance.get_node_or_null("ObjectSpawnerFromTileMap") as ObjectSpawnerFromTileMap
	if map_object_spawner != null:
		map_object_spawner.auto_spawn_on_ready = false
		map_object_spawner.allow_duplicate_spawn = false


func _replace_battle_map(new_battle_map: BattleMap) -> void:
	if new_battle_map == null:
		return

	var old_battle_map: BattleMap = battle_map
	var insert_index: int = get_child_count()
	if old_battle_map != null and old_battle_map.get_parent() == self:
		insert_index = old_battle_map.get_index()
		old_battle_map.remove_from_group("battle_map")
		remove_child(old_battle_map)
		detached_fallback_battle_map = old_battle_map

	add_child(new_battle_map)
	move_child(new_battle_map, clamp(insert_index, 0, get_child_count() - 1))
	battle_map = new_battle_map
	if enemy_spawner != null:
		enemy_spawner.battle_map = battle_map


# 让战斗地图统一负责出生点数据，PlayScene 只在进入战斗时读取一次。
func _initialize_battle_map() -> void:
	if battle_map == null:
		return

	battle_map.refresh_layer_cache()
	battle_map.configure_depth_sorting()
	if player != null:
		player.global_position = battle_map.get_player_spawn_position(player.global_position)
	if enemy_spawner != null:
		enemy_spawner.battle_map = battle_map
	_initialize_object_spawner()
	_initialize_terrain_randomizer()
	_validate_battle_map_generation()
	_initialize_terrain_effect_controller()


## 地图物体和特殊地形都生成后，检查最终地图是否满足战斗的基本条件。
func _validate_battle_map_generation() -> void:
	if battle_map == null or not validate_battle_map_generation:
		return

	battle_map_generation_validator = BattleMapGenerationValidator.new()
	battle_map_generation_validator.battle_map = battle_map
	battle_map_generation_validator.minimum_reachable_ratio = map_validation_min_reachable_ratio
	battle_map_generation_validator.log_result = log_battle_map_validation
	var report: Dictionary = battle_map_generation_validator.validate_and_repair()
	var safe_player_position: Variant = report.get("recommended_player_spawn_position")
	if player != null and safe_player_position is Vector2:
		player.global_position = safe_player_position as Vector2


func _initialize_object_spawner() -> void:
	if battle_map == null:
		return

	object_spawner = battle_map.get_node_or_null("ObjectSpawnerFromTileMap") as ObjectSpawnerFromTileMap
	if object_spawner == null:
		object_spawner = ObjectSpawnerFromTileMap.new()
		object_spawner.name = "ObjectSpawnerFromTileMap"
		battle_map.add_child(object_spawner)

	# 地图物件必须在战斗正式开始前生成，这样玩家技能、敌人和掉落逻辑都能正常找到它们。
	object_spawner.bind_battle_map(battle_map)
	object_spawner.bind_run_stats(run_stats)
	object_spawner.spawn_objects()


func _initialize_terrain_randomizer() -> void:
	if battle_map == null:
		return

	terrain_randomizer = battle_map.get_node_or_null("BattleMapTerrainRandomizer") as BattleMapTerrainRandomizer
	if terrain_randomizer == null:
		terrain_randomizer = BattleMapTerrainRandomizer.new()
		terrain_randomizer.name = "BattleMapTerrainRandomizer"
		battle_map.add_child(terrain_randomizer)

	# 读取特殊地形生成资源，把火海、冰面等规则化地铺到 EffectLayer 上。
	terrain_randomizer.bind_battle_map(battle_map)
	terrain_randomizer.bind_run_stats(run_stats)
	terrain_randomizer.randomize_terrain()


func _initialize_terrain_effect_controller() -> void:
	if battle_map == null:
		return
	if terrain_effect_controller != null and is_instance_valid(terrain_effect_controller):
		terrain_effect_controller.bind_battle_map(battle_map)
		return

	# 地形规则层由 PlayScene 自动创建，避免每张战斗地图都手动摆一个控制器节点。
	terrain_effect_controller = TerrainEffectController.new()
	terrain_effect_controller.name = "TerrainEffectController"
	add_child(terrain_effect_controller)
	terrain_effect_controller.bind_battle_map(battle_map)


# 开启战斗世界的 y-sort。具体地面/山丘图层怎么排序由 BattleMap 自己配置。
func _configure_world_depth_sorting() -> void:
	y_sort_enabled = true
	if battle_map != null:
		battle_map.configure_depth_sorting()
	if player != null:
		player.z_index = 0
		player.z_as_relative = true


func _initialize_battle_tag_effect_controller() -> void:
	if run_stats == null or run_stats.player_build == null or player == null:
		return

	_ensure_default_tag_effect_selection()

	tag_effect_controller = TagEffectController.new()
	tag_effect_controller.name = "BattleTagEffectController"
	add_child(tag_effect_controller)
	tag_effect_controller.bind_context(run_stats, player, _load_default_tag_effects())


func _cleanup_battle_tag_effect_controller() -> void:
	if tag_effect_controller == null:
		return

	tag_effect_controller.queue_free()
	tag_effect_controller = null


func _load_default_tag_effects() -> Array[TagEffect]:
	var database := TAG_EFFECT_DATABASE.duplicate(true) as TagEffectDatabase
	database.load_selection()
	return database.get_selected_effects()


func _ensure_default_tag_effect_selection() -> void:
	if run_stats == null:
		return

	var default_effects: Array[TagEffect] = _load_default_tag_effects()
	if run_stats.selected_tag_effects.is_empty():
		run_stats.selected_tag_effects = default_effects
		return

	var used_tag_keys: Array[String] = []
	for effect: TagEffect in run_stats.selected_tag_effects:
		if effect == null:
			continue
		var tag_key: String = effect.get_tag_key()
		if tag_key.is_empty() or used_tag_keys.has(tag_key):
			continue
		used_tag_keys.append(tag_key)

	for default_effect: TagEffect in default_effects:
		if default_effect == null:
			continue
		var default_tag_key: String = default_effect.get_tag_key()
		if default_tag_key.is_empty() or used_tag_keys.has(default_tag_key):
			continue

		# 兼容直接运行 PlayScene 或旧存档继续战斗：只补新增 tag 的默认效果，不覆盖已有选择。
		run_stats.selected_tag_effects.append(default_effect)
		used_tag_keys.append(default_tag_key)


# 玩家死亡后不再原地复活，而是交给 Run 打开死亡界面。
func _handle_game_over(_dead_player: Player) -> void:
	var tween: Tween = fade_in_overlay()
	await tween.finished
	_sync_player_build_state()
	EventBus.battle_lost.emit()


# 地图结束点的请求也必须走同一条结算链，避免和普通战斗胜利产生两套逻辑。
func _handle_battle_end_requested(source: Node, skip_level_up: bool) -> void:
	if source == null or not is_instance_valid(source):
		return
	if not source.is_in_group("battle_end_point"):
		return

	_handle_battle_completed(skip_level_up)


# 用无参数转发函数连接 EnemySpawner，避免信号连接依赖 GDScript 默认参数。
func _on_enemy_spawner_battle_completed() -> void:
	_handle_battle_completed(false)


# EnemySpawner 判断整场战斗完成后，先同步玩家状态，再进入奖励/结算流程。
func _handle_battle_completed(skip_level_up: bool) -> void:
	if battle_completion_started:
		return
	battle_completion_started = true
	_restore_health_after_battle()
	_sync_player_build_state()
	var tween: Tween = fade_in_overlay()
	await tween.finished

	EventBus.battle_rewards_resolving.emit()
	if run_stats != null and run_stats.player_build != null:
		run_stats.player_build.clear_temporary_relics()
	if _is_boss_battle_completed():
		EventBus.game_victory.emit()
		return

	if skip_level_up:
		EventBus.battle_win_direct_to_rest.emit()
	else:
		EventBus.battle_win.emit()


func _handle_bounty_enemy_killed(_enemy: Entity, killer: Entity, bounty_gold: int) -> void:
	if run_stats == null or bounty_gold <= 0:
		return
	if killer != null and is_instance_valid(killer) and not killer.is_player_side():
		return

	run_stats.set_gold(run_stats.gold + bounty_gold)


# 消费 RunStats 中由事件/遗物排队的额外悬赏精英怪。
# EnemySpawner 会把它们登记为 bounty，不计入正常战斗胜利条件。
func _spawn_pending_bounty_enemies() -> void:
	if run_stats == null or enemy_spawner == null:
		return

	var entries: Array[BountyEnemyEntry] = run_stats.pop_pending_bounty_enemy_entries()
	for entry: BountyEnemyEntry in entries:
		if entry == null:
			continue
		enemy_spawner.spawn_bounty_enemy(entry)


func _setup_bounty_hint_ui() -> void:
	# 悬赏提示现在统一进入左侧战斗消息列表，这里保留函数入口避免 ready 流程分散。
	pass


func _handle_bounty_enemy_presence_changed(has_bounty_enemy: bool) -> void:
	if has_bounty_enemy and not has_active_bounty_hint:
		FloatText.show_screen_tip("稀有的悬赏精英怪已出现，有实力者可以前去挑战")

	has_active_bounty_hint = has_bounty_enemy


func _is_boss_battle_completed() -> bool:
	return pending_battle_stats != null and pending_battle_stats.battle_tier == 3


# 屏幕淡出。
func fade_out_overlay() -> Tween:
	var tween := create_tween()
	tween.tween_property(
		screen_transition,
		"color:a",
		0.0,
		1.0
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	return tween


# 屏幕淡入。
func fade_in_overlay() -> Tween:
	var tween := create_tween()
	tween.tween_property(
		screen_transition,
		"color:a",
		1.0,
		1.0
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	return tween


# 响应 Run 场景的全局暂停状态，只负责战斗场景遮罩，不再弹出独立 PauseMenu。
func _handle_pause(paused: bool) -> void:
	if screen_transition == null:
		return

	if paused:
		screen_transition.color = Color(0, 0, 0, 0.5)
	else:
		screen_transition.color = Color(0, 0, 0, 0)


# 把战斗中玩家的生命和能量写回 PlayerBuild，修整期看到的就是战斗后的真实状态。
func _sync_player_build_state() -> void:
	if run_stats == null or run_stats.player_build == null or player == null:
		return

	run_stats.player_build.current_health = player.current_health
	run_stats.player_build.current_energy = player.current_energy


# 每场战斗胜利后，按照当前体质点数恢复生命值。
func _restore_health_after_battle() -> void:
	if player == null or player.stats_controller == null:
		return

	var heal_amount: float = player.stats_controller.get_stat(&"constitution")
	if heal_amount <= 0.0:
		return

	# 统一治疗入口会读取运行时最大生命，并同步 StatsController、PlayerBuild 和生命 UI。
	player.apply_heal(heal_amount)


# 进入战斗时刷新主动/被动技能栏，确保 UI 使用本局 PlayerBuild 的技能数据。
func _refresh_skill_ui() -> void:
	if player != null and spell_bar != null and player.ability_controller != null:
		spell_bar.refresh_from_controller(player.ability_controller)

	if passive_skill_bar != null:
		var player_build := run_stats.player_build if run_stats != null else null
		passive_skill_bar.refresh_from_player_build(player_build)


# 刷新左上角消耗品栏，只显示装备栏里的第一个消耗品。
func _refresh_consumable_ui() -> void:
	if consumable_container == null:
		return

	consumable_container.set_relic(_get_equipped_consumable_relic())


# 绑定玩家身上的 StatusController，让状态 UI 跟随当前状态自动刷新。
func _bind_player_status_ui() -> void:
	_unbind_player_status_ui()
	if player == null:
		_refresh_status_ui()
		return

	bound_status_controller = player.get_status_controller()
	if bound_status_controller == null:
		_refresh_status_ui()
		return

	if not bound_status_controller.status_changed.is_connected(_refresh_status_ui):
		bound_status_controller.status_changed.connect(_refresh_status_ui)
	_refresh_status_ui()


# 离开战斗场景时断开状态信号，避免旧场景残留回调。
func _unbind_player_status_ui() -> void:
	if bound_status_controller != null and bound_status_controller.status_changed.is_connected(_refresh_status_ui):
		bound_status_controller.status_changed.disconnect(_refresh_status_ui)
	bound_status_controller = null


# 根据 StatusController 当前保存的状态重建图标列表。
func _refresh_status_ui() -> void:
	if status_container == null:
		return

	_clear_status_ui()
	if bound_status_controller == null:
		return

	for status_instance in bound_status_controller.statuses.values():
		var instance := status_instance as StatusInstance
		if instance == null:
			continue

		var status_ui := STATUS_UI_SCENE.instantiate() as StatusUI
		status_container.add_child(status_ui)
		status_ui.setup(instance)


# 清空容器中的旧图标。场景里预放的 StatusUI 也会被当作占位节点清掉。
func _clear_status_ui() -> void:
	for child in status_container.get_children():
		child.queue_free()


# Q 使用消耗品入口：攻击型消耗品会先进入瞄准预览，普通消耗品仍然直接使用。
func _begin_or_use_equipped_consumable() -> void:
	var consumable_data := _get_equipped_consumable_data()
	var relic := consumable_data.get("relic") as Relic
	if relic == null:
		return

	var aim_effect := _get_consumable_aim_effect(relic)
	if aim_effect == null:
		_use_equipped_consumable()
		return

	_begin_consumable_preview(aim_effect, int(consumable_data.get("slot_index", -1)))


func _begin_consumable_preview(aim_effect: UseSpawnManifestEffect, slot_index: int) -> void:
	if player == null or aim_effect == null:
		return

	_cancel_consumable_preview()
	previewing_consumable_effect = aim_effect
	previewing_consumable_slot_index = slot_index

	consumable_preview_indicator = AbilityAreaIndicator.new()
	add_child(consumable_preview_indicator)
	aim_effect.configure_indicator(consumable_preview_indicator)

	var context := AbilityContext.new(player, null)
	consumable_preview_indicator.begin_preview(context)


func _release_equipped_consumable_preview() -> void:
	if previewing_consumable_effect == null:
		return

	var target_position := previewing_consumable_effect.get_aim_target_position(player)
	var slot_index := previewing_consumable_slot_index
	_cancel_consumable_preview()
	_use_equipped_consumable(target_position, slot_index)


func _cancel_consumable_preview() -> void:
	if consumable_preview_indicator != null and is_instance_valid(consumable_preview_indicator):
		consumable_preview_indicator.end_preview()
		consumable_preview_indicator.queue_free()

	consumable_preview_indicator = null
	previewing_consumable_effect = null
	previewing_consumable_slot_index = -1


func _get_consumable_aim_effect(relic: Relic) -> UseSpawnManifestEffect:
	if relic == null:
		return null

	for effect in relic.effects:
		if effect is UseSpawnManifestEffect and (effect as UseSpawnManifestEffect).has_aim_preview():
			return effect as UseSpawnManifestEffect

	if relic.leveltip == Relic.LevelTip.LEVELUP:
		for effect in relic.great_effects:
			if effect is UseSpawnManifestEffect and (effect as UseSpawnManifestEffect).has_aim_preview():
				return effect as UseSpawnManifestEffect

	return null


# Q 使用消耗品：触发遗物 use 效果，然后从装备栏移除。
func _use_equipped_consumable(target_position: Variant = null, expected_slot_index: int = -1) -> void:
	if player == null or run_stats == null or run_stats.player_build == null:
		return

	var equipment := run_stats.player_build.player_equipment
	if equipment == null:
		return

	var consumable_slot_index := _find_equipped_consumable_slot_index(equipment)
	if consumable_slot_index < 0:
		return
	if expected_slot_index >= 0 and consumable_slot_index != expected_slot_index:
		return

	var slot := equipment.equip_slots[consumable_slot_index]
	if slot == null or slot.item == null:
		return

	var relic := slot.item
	if not relic.is_consumable:
		return

	consumable_use_count += 1
	var relic_key := "consumable_use_%s_%s_%s" % [consumable_slot_index, relic.id, consumable_use_count]
	relic.use_consumable(player, player.relic_controller, relic_key, target_position)
	EventBus.consumable_used.emit(relic, player)
	EventBus.relic_removed.emit(relic, "used")

	var should_keep_consumable := run_stats.roll_keep_consumable()
	if not should_keep_consumable:
		slot.item = null
		EventBus.equipment_update.emit()
	else:
		AudioController.play_ui_sound(&"get_item")

	EventBus.attribute_update.emit()
	_refresh_consumable_ui()
	_sync_player_build_state()


func _get_equipped_consumable_data() -> Dictionary:
	if run_stats == null or run_stats.player_build == null:
		return {}

	var equipment := run_stats.player_build.player_equipment
	if equipment == null:
		return {}

	var slot_index := _find_equipped_consumable_slot_index(equipment)
	if slot_index < 0:
		return {}

	var slot := equipment.equip_slots[slot_index]
	if slot == null or slot.item == null or not slot.item.is_consumable:
		return {}

	return {
		"slot_index": slot_index,
		"relic": slot.item,
	}


func _get_equipped_consumable_relic() -> Relic:
	if run_stats == null or run_stats.player_build == null:
		return null

	var equipment := run_stats.player_build.player_equipment
	if equipment == null:
		return null

	var slot_index := _find_equipped_consumable_slot_index(equipment)
	if slot_index < 0:
		return null

	var slot := equipment.equip_slots[slot_index]
	return slot.item if slot != null else null


func _find_equipped_consumable_slot_index(equipment: Equipment) -> int:
	if equipment == null:
		return -1

	for slot_index in range(equipment.equip_slots.size()):
		var slot := equipment.equip_slots[slot_index]
		if slot == null or slot.item == null:
			continue
		if slot.item.is_consumable:
			return slot_index

	return -1


# 向上查找当前 PlayScene 是否挂在 Run 节点下，保留给后续需要直接调用 Run 流程的地方。
func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()

	return null
