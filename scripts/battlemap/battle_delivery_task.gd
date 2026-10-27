## 一场战斗内的配送状态机：待取货 -> 配送中 -> 完成/取消。
## 任务挂在拥有者下，场景退出自动撤销加成；不保存未完成任务到局外。
class_name BattleDeliveryTask
extends Node

signal stage_changed(stage: int)
enum Stage { WAITING, CARRYING, COMPLETED, CANCELLED }

var configuration: BattleDeliveryEffect
var context: RelicContext
var equipped: bool = true
var stage: int = Stage.WAITING
var started: bool = false
var cargo: DeliveryMarker
var destination: DeliveryMarker
var chosen: WeightedRelicEffectOption
var scene: PlayScene
var target_position: Vector2
var hint: Label
var tracking_hint: Label
var effect_active: bool = false
var retry_timer: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(context.owner) or (context.owner as Entity).is_dead:
		cancel()
		return
	if is_instance_valid(scene) and scene.battle_completion_started:
		cancel()
		return
	if started and not EventBus.is_battle_active:
		cancel()
		return
	if not started and equipped and EventBus.is_battle_active:
		retry_timer -= delta
		if retry_timer <= 0.0:
			retry_timer = 1.0
			start.call_deferred()
	_update_hint()


func start() -> void:
	if started or not equipped or not EventBus.is_battle_active:
		return
	var parent_node: Node = context.owner
	while parent_node != null and not (parent_node is PlayScene):
		parent_node = parent_node.get_parent()
	scene = parent_node as PlayScene
	if scene == null or scene.battle_map == null or configuration.cargo_scene == null:
		return
	var origin: Vector2 = (context.owner as Entity).global_position
	var position_value: Variant = _pick_position(origin)
	if not (position_value is Vector2):
		return
	var target_value: Variant = _pick_position(position_value as Vector2)
	if not (target_value is Vector2):
		return
	chosen = _pick_option()
	if chosen == null or configuration.destination_scene == null:
		return
	target_position = target_value as Vector2
	cargo = _spawn_marker(configuration.cargo_scene, position_value as Vector2, false)
	if cargo == null:
		return
	started = true
	_create_tracking_hint()
	_message("配送货物已出现，请前往取货。")


func _pick_position(reference: Vector2) -> Variant:
	var map: BattleMap = scene.battle_map
	var value: Variant = map.get_random_playable_position(reference, configuration.minimum_distance)
	# 小地图允许缩短配送距离，但绝不回退到任意场外坐标。
	if value == null:
		value = map.get_random_playable_position(reference, 0.0)
	return value


func _pick_option() -> WeightedRelicEffectOption:
	var total: float = 0.0
	for option: WeightedRelicEffectOption in configuration.cargo_options:
		if option != null and option.is_available(context):
			total += option.weight
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for option: WeightedRelicEffectOption in configuration.cargo_options:
		if option == null or not option.is_available(context):
			continue
		roll -= option.weight
		if roll <= 0.0:
			return option
	return null


func _spawn_marker(packed: PackedScene, position_value: Vector2, target: bool) -> DeliveryMarker:
	var instance: Node = packed.instantiate()
	if not (instance is DeliveryMarker):
		instance.queue_free()
		return null
	var marker: DeliveryMarker = instance as DeliveryMarker
	marker.task = self
	marker.is_destination = target
	if not target and chosen != null:
		marker.cargo_icon = chosen.icon
	var container: Node = scene.battle_map.get_runtime_effect_container()
	if container == null:
		container = scene.battle_map
	container.add_child(marker)
	marker.global_position = position_value
	return marker


func can_interact(collector: Entity) -> bool:
	return equipped and EventBus.is_battle_active and collector == context.owner \
		and is_instance_valid(scene) and not scene.battle_completion_started \
		and (stage == Stage.WAITING or stage == Stage.CARRYING)


func collect_cargo() -> void:
	if stage != Stage.WAITING or not can_interact(context.owner as Entity):
		return
	destination = _spawn_marker(configuration.destination_scene, target_position, true)
	if destination == null:
		cancel()
		return
	stage = Stage.CARRYING
	effect_active = true
	_apply_effects(true)
	stage_changed.emit(stage)
	_message("拾取配送货物：%s；送达后撤销加成。" % chosen.option_name)


func deliver() -> void:
	if stage != Stage.CARRYING or not can_interact(context.owner as Entity):
		return
	if not is_instance_valid(scene) or scene.run_stats == null:
		cancel()
		return
	var reward: int = configuration.upgraded_gold_reward if context.own_relic.leveltip == Relic.LevelTip.LEVELUP else configuration.gold_reward
	stage = Stage.COMPLETED
	_clear_objects_and_effects()
	scene.run_stats.set_gold(scene.run_stats.gold + reward)
	stage_changed.emit(stage)
	_message("配送完成，获得%d金币。" % reward)


func _apply_effects(activate: bool) -> void:
	if chosen == null or not is_instance_valid(context.owner):
		return
	# 切场景时同级属性/装备控制器可能已被释放，不能再调用已销毁对象。
	if not is_instance_valid((context.owner as Entity).stats_controller):
		return
	if not is_instance_valid(context.relic_controller):
		context.relic_controller = null
	for index: int in range(chosen.effects.size()):
		var effect: RelicEffect = chosen.effects[index]
		if effect == null:
			continue
		var key: String = "delivery_%s_%s" % [get_instance_id(), index]
		if activate:
			effect.on_activate(context, key)
		else:
			effect.on_deactivate(context, key)


func cancel_if_unequipped() -> void:
	if not equipped:
		cancel()


func cancel() -> void:
	if stage == Stage.COMPLETED or stage == Stage.CANCELLED:
		return
	stage = Stage.CANCELLED
	started = true
	_clear_objects_and_effects()
	stage_changed.emit(stage)
	set_process(false)


func _clear_objects_and_effects() -> void:
	if effect_active:
		effect_active = false
		_apply_effects(false)
	for object: Node in [cargo, destination, tracking_hint]:
		if is_instance_valid(object) and not object.is_queued_for_deletion():
			object.queue_free()


func _exit_tree() -> void:
	_clear_objects_and_effects()


func _update_hint() -> void:
	var marker: DeliveryMarker = cargo if stage == Stage.WAITING else destination
	if not is_instance_valid(marker) or not is_instance_valid(context.owner):
		return
	hint = marker.get_node_or_null("Hint") as Label
	if hint == null:
		return
	var offset: Vector2 = marker.global_position - (context.owner as Entity).global_position
	var directions: Array[String] = ["东", "东南", "南", "西南", "西", "西北", "北", "东北"]
	var direction_index: int = posmod(roundi(offset.angle() / (PI / 4.0)), 8)
	# 提示随玩家移动更新，关卡消息只在状态切换时添加，避免刷屏。
	hint.text = "%s：%s方 %d" % ["取货" if stage == Stage.WAITING else "送达", directions[direction_index], roundi(offset.length())]
	if is_instance_valid(tracking_hint):
		tracking_hint.text = hint.text


func _create_tracking_hint() -> void:
	# 简单文字导航不依赖货物是否在视野内，也不虚构货物美术。
	tracking_hint = Label.new()
	tracking_hint.position = Vector2(-85.0, -65.0)
	tracking_hint.size = Vector2(170.0, 20.0)
	tracking_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tracking_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracking_hint.add_theme_font_size_override("font_size", 12)
	tracking_hint.add_theme_constant_override("outline_size", 3)
	tracking_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(tracking_hint)


func _message(text: String) -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group("battle_message_log"):
		if node is BattleMessageLog:
			(node as BattleMessageLog).add_message(text)
