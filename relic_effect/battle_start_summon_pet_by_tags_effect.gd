## 遗物效果：战斗开始时按指定 tag 计数召唤友方召唤物。
## 适合“放映机”“环之枪”等开场召唤盟友类装备；每个 tag 独立计数，因此同一件装备同时拥有两个目标 tag 会贡献 2 次。
class_name BattleStartSummonPetByTagsEffect
extends RelicEffect

## 要召唤的召唤物场景，根节点建议继承 SummonPet。
@export var pet_scene: PackedScene
## 普通状态下覆盖召唤物 StatsController 的属性资源；为空则使用场景里原本配置。
@export var normal_pet_stats: StatsData
## 升级态覆盖召唤物 StatsController 的属性资源；为空则沿用 normal_pet_stats 或场景默认配置。
@export var levelup_pet_stats: StatsData
## 参与计数的 tag。每个 tag 独立判断，同一遗物同时拥有多个目标 tag 会多次计数。
@export var counted_tags: Array[RelicTag] = []
## 固定召唤数量。适合“至少召唤 1 只，然后再按 tag 追加”的装备。
@export var base_summon_count: int = 0
## 是否统计装备栏。
@export var count_equipment: bool = true
## 是否统计背包。放映机默认只看“装备的其它装备”，所以这里默认关闭。
@export var count_inventory: bool = false
## 开启后，一件遗物只要命中任意目标 tag 就只计 1 次。
## 关闭时保留旧逻辑：一件遗物同时带两个目标 tag 会计 2 次。
@export var count_each_relic_once: bool = false
## 是否排除这件遗物自身。
@export var exclude_self_relic: bool = true
## 最大召唤数量；0 表示不限制。
@export var max_summon_count: int = 0

@export_group("生成位置")
@export var min_spawn_distance: float = 42.0
@export var spawn_radius: float = 96.0
@export var random_angle_offset: bool = true
@export var spawn_parent_path: NodePath

@export_group("召唤物行为")
@export var normal_ability_select_mode: SummonPet.AbilitySelectMode = SummonPet.AbilitySelectMode.FIRST_READY
@export var levelup_ability_select_mode: SummonPet.AbilitySelectMode = SummonPet.AbilitySelectMode.RANDOM_READY
@export var play_spawn_animation: bool = true
@export var spawn_animation_name: StringName = &"appear"

var active_callbacks: Dictionary = {}
var active_pets: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if pet_scene == null:
		return
	if counted_tags.is_empty() and base_summon_count <= 0:
		return

	var key := str(effect_key)
	if active_callbacks.has(key):
		return

	if EventBus.is_battle_active:
		_on_battle_started(relic_context, key)
		return

	var callback := Callable(self, "_on_battle_started").bind(relic_context, key)
	EventBus.battle_started.connect(callback, CONNECT_ONE_SHOT)
	active_callbacks[key] = callback


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if active_callbacks.has(key):
		var callback := active_callbacks[key] as Callable
		if EventBus.battle_started.is_connected(callback):
			EventBus.battle_started.disconnect(callback)
		active_callbacks.erase(key)

	_clear_spawned_pets(key)


func _on_battle_started(relic_context: RelicContext, effect_key: String) -> void:
	active_callbacks.erase(effect_key)
	if relic_context == null or not (relic_context.owner is Entity):
		return

	var owner := relic_context.owner as Entity
	if not is_instance_valid(owner) or owner.is_dead:
		return

	var summon_count := _get_summon_count(relic_context)
	if summon_count <= 0:
		return

	var parent := _resolve_spawn_parent(owner)
	if parent == null:
		return

	active_pets[effect_key] = []
	var spawn_offsets := _build_spawn_offsets(summon_count)
	for offset in spawn_offsets:
		_spawn_one_pet(parent, owner, owner.global_position + offset, relic_context, effect_key)


func _spawn_one_pet(parent: Node, summoner: Entity, spawn_position: Vector2, relic_context: RelicContext, effect_key: String) -> void:
	var node := pet_scene.instantiate() as Node2D
	if node == null:
		return

	var pet := node as SummonPet
	_prepare_pet_before_ready(node, pet, relic_context)
	parent.add_child(node)
	node.global_position = spawn_position

	if pet != null:
		pet.set_summoner(summoner)
		if play_spawn_animation:
			pet.call_deferred("play_spawn_animation", spawn_animation_name)

	var pets := active_pets.get(effect_key, []) as Array
	pets.append(node)
	active_pets[effect_key] = pets


func _prepare_pet_before_ready(node: Node2D, pet: SummonPet, relic_context: RelicContext) -> void:
	var stats_controller := node.get_node_or_null("StatsController") as StatsController
	var stats_data := _get_pet_stats(relic_context)
	if stats_controller != null and stats_data != null:
		stats_controller.stats_data = stats_data

	if pet != null:
		pet.ability_select_mode = _get_pet_ability_select_mode(relic_context)


func _get_summon_count(relic_context: RelicContext) -> int:
	var count = max(base_summon_count, 0)
	for relic in _get_counted_relics(relic_context):
		if relic == null:
			continue
		if exclude_self_relic and relic == relic_context.own_relic:
			continue

		count += _count_matching_tags(relic)

	if max_summon_count > 0:
		count = min(count, max_summon_count)
	return max(count, 0)


func _get_counted_relics(relic_context: RelicContext) -> Array[Relic]:
	var result: Array[Relic] = []
	var player_build := _get_player_build(relic_context)

	if count_equipment:
		var equipment := _get_equipment(relic_context, player_build)
		if equipment != null:
			for slot in equipment.equip_slots:
				if slot != null and slot.item != null:
					result.append(slot.item)

	if count_inventory and player_build != null and player_build.player_inventory != null:
		for slot in player_build.player_inventory.slots:
			if slot != null and slot.item != null:
				result.append(slot.item)

	return result


func _count_matching_tags(relic: Relic) -> int:
	var count := 0
	for target_tag in counted_tags:
		if _relic_has_tag(relic, target_tag):
			if count_each_relic_once:
				return 1
			count += 1
	return count


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag:
			return true
		if not relic_tag.tag_name.is_empty() and relic_tag.tag_name == target_tag.tag_name:
			return true
	return false


func _build_spawn_offsets(summon_count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var safe_count = max(summon_count, 1)
	var safe_radius = max(spawn_radius, min_spawn_distance)
	var base_angle := randf() * TAU if random_angle_offset else 0.0

	for index in range(safe_count):
		var angle := base_angle + TAU * float(index) / float(safe_count)
		var distance := randf_range(min_spawn_distance, safe_radius)
		result.append(Vector2.RIGHT.rotated(angle) * distance)

	return result


func _get_pet_stats(relic_context: RelicContext) -> StatsData:
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_pet_stats != null:
		return levelup_pet_stats
	return normal_pet_stats


func _get_pet_ability_select_mode(relic_context: RelicContext) -> SummonPet.AbilitySelectMode:
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return levelup_ability_select_mode
	return normal_ability_select_mode


func _resolve_spawn_parent(owner: Entity) -> Node:
	if spawn_parent_path != NodePath():
		var from_owner := owner.get_node_or_null(spawn_parent_path)
		if from_owner != null:
			return from_owner

		var current_scene := owner.get_tree().current_scene
		if current_scene != null:
			var from_scene := current_scene.get_node_or_null(spawn_parent_path)
			if from_scene != null:
				return from_scene

	if owner.get_parent() != null:
		return owner.get_parent()

	return owner.get_tree().current_scene if owner.get_tree().current_scene != null else owner.get_tree().root


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is Entity:
		var owner := relic_context.owner as Entity
		if owner.stats_controller != null:
			return owner.stats_controller.player_build
	return null


func _get_equipment(relic_context: RelicContext, player_build: PlayerBuild) -> Equipment:
	if player_build != null:
		return player_build.player_equipment
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.equipment_inventory
	if "player_equipment" in relic_context.owner:
		return relic_context.owner.player_equipment
	return null


func _clear_spawned_pets(effect_key: String) -> void:
	var pets := active_pets.get(effect_key, []) as Array
	for pet in pets:
		# 场景切换时召唤物可能已经先被树释放。
		# 必须先 is_instance_valid，再做类型判断，否则 Godot 会对“已释放实例”执行 is 判断并报错。
		if not is_instance_valid(pet):
			continue

		var pet_node := pet as Node
		if pet_node != null:
			pet_node.queue_free()
	active_pets.erase(effect_key)
