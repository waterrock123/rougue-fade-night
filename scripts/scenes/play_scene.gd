class_name PlayScene
extends Node

const REST_PERIOD_SCENE := preload("res://scenes/rest_period/rest_period.tscn")
const STATUS_UI_SCENE := preload("res://scenes/ui/status_ui.tscn")
const TAG_EFFECT_DATABASE := preload("res://custom_resource/default_tag_effect_database.tres")

@export var screen_transition: ColorRect
@export var player_health_bar: PlayerHealthBar
@export var run_stats: RunStats

var player: Player
var pending_battle_stats: BattleStats
var bound_status_controller: StatusController
var consumable_preview_indicator: AbilityAreaIndicator
var previewing_consumable_effect: UseSpawnManifestEffect
var previewing_consumable_slot_index: int = -1
var tag_effect_controller: TagEffectController

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var spell_bar: SpellBar = $CanvasLayer/UI/SpellBar
@onready var passive_skill_bar: PassiveSkillBar = $CanvasLayer/UI/PassiveSkillBar
@onready var consumable_container: ConsumableContainer = $CanvasLayer/UI/ConsumableContainer
@onready var status_container: GridContainer = $CanvasLayer/UI/StatusContainer

var consumable_use_count := 0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Player
	if run_stats != null and run_stats.player_build != null and player != null:
		player.bind_player_build(run_stats.player_build)
		_initialize_battle_tag_effect_controller()

	_refresh_skill_ui()
	_refresh_consumable_ui()
	_bind_player_status_ui()

	if enemy_spawner != null and pending_battle_stats != null:
		enemy_spawner.battle_stats = pending_battle_stats

	if player != null and not player.player_died.is_connected(_handle_game_over):
		player.player_died.connect(_handle_game_over)
	if enemy_spawner != null and not enemy_spawner.battle_completed.is_connected(_handle_battle_completed):
		enemy_spawner.battle_completed.connect(_handle_battle_completed)

	AudioController.play_bg_music("battle")
	if not EventBus.game_paused.is_connected(_handle_pause):
		EventBus.game_paused.connect(_handle_pause)
	if not EventBus.equipment_update.is_connected(_refresh_consumable_ui):
		EventBus.equipment_update.connect(_refresh_consumable_ui)

	# 所有玩家构筑、装备效果和 UI 都初始化完后，再通知“进场触发”效果结算。
	EventBus.battle_started.emit()


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_handle_pause):
		EventBus.game_paused.disconnect(_handle_pause)
	if EventBus.equipment_update.is_connected(_refresh_consumable_ui):
		EventBus.equipment_update.disconnect(_refresh_consumable_ui)
	_unbind_player_status_ui()
	_cleanup_battle_tag_effect_controller()
	_cancel_consumable_preview()


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


func _initialize_battle_tag_effect_controller() -> void:
	if run_stats == null or run_stats.player_build == null or player == null:
		return

	if run_stats.selected_tag_effects.is_empty():
		run_stats.selected_tag_effects = _load_default_tag_effects()

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


# 玩家死亡后不再原地复活，而是交给 Run 打开死亡界面。
func _handle_game_over(_dead_player: Player) -> void:
	var tween: Tween = fade_in_overlay()
	await tween.finished
	_sync_player_build_state()
	EventBus.battle_lost.emit()


# EnemySpawner 判断整场战斗完成后，先同步玩家状态，再进入奖励/结算流程。
func _handle_battle_completed() -> void:
	_restore_health_after_battle()
	_sync_player_build_state()
	var tween: Tween = fade_in_overlay()
	await tween.finished

	EventBus.battle_rewards_resolving.emit()
	EventBus.battle_win.emit()


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

	var heal_amount := player.stats_controller.get_stat(&"constitution")
	if heal_amount <= 0.0:
		return

	player.current_health = min(player.current_health + heal_amount, player.max_health)
	player.stats_controller.current_health = player.current_health
	player.stats_controller.sync_runtime_resources()
	EventBus.player_health_changed.emit(player.current_health, player.max_health)


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
