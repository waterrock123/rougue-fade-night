## 遗物效果：每场战斗第一次受到实际伤害时召唤友方召唤物。
## 适合“精灵辉尘”这类受击触发的保护型装备；触发后本场战斗不会再次触发。
class_name FirstDamageSummonPetEffect
extends RelicEffect

## 要召唤的召唤物场景，根节点建议继承 SummonPet。
@export var pet_scene: PackedScene
## 普通状态下覆盖召唤物 StatsController 的属性资源；为空则使用场景自身配置。
@export var normal_pet_stats: StatsData
## 升级态覆盖召唤物 StatsController 的属性资源；为空则沿用 normal_pet_stats 或场景默认配置。
@export var levelup_pet_stats: StatsData
## 未升级时召唤数量。
@export var summon_count: int = 1
## 升级态额外召唤数量。精灵辉尘升级后会在基础数量上额外 +1。
@export var levelup_extra_count: int = 1
## 是否要求 final_damage > 0 才触发，避免无敌/闪避/0伤害也消耗本场次数。
@export var require_positive_damage: bool = true

@export_group("生成位置")
@export var min_spawn_distance: float = 42.0
@export var spawn_radius: float = 96.0
@export var random_angle_offset: bool = true
@export var spawn_parent_path: NodePath

@export_group("召唤物行为")
@export var normal_ability_select_mode: SummonPet.AbilitySelectMode = SummonPet.AbilitySelectMode.FIRST_READY
@export var levelup_ability_select_mode: SummonPet.AbilitySelectMode = SummonPet.AbilitySelectMode.FIRST_READY
@export var play_spawn_animation: bool = true
@export var spawn_animation_name: StringName = &"appear"

var active_entries: Dictionary = {}
var active_pets: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner = _get_owner_entity(relic_context)
	if owner == null or pet_scene == null:
		return

	var key = str(effect_key)
	if active_entries.has(key):
		return

	active_entries[key] = {
		"owner": owner,
		"relic_context": relic_context,
		"battle_callback": Callable(),
		"damage_callback": Callable(),
		"triggered": false,
	}

	if EventBus.is_battle_active:
		_arm_damage_listener(key)
	else:
		var battle_callback = Callable(self, "_on_battle_started").bind(key)
		active_entries[key]["battle_callback"] = battle_callback
		EventBus.battle_started.connect(battle_callback, CONNECT_ONE_SHOT)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key = str(effect_key)
	_disconnect_entry(key)
	_clear_spawned_pets(key)


func _on_battle_started(effect_key: String) -> void:
	_arm_damage_listener(effect_key)


func _arm_damage_listener(effect_key: String) -> void:
	if not active_entries.has(effect_key):
		return

	var entry = active_entries[effect_key] as Dictionary
	var owner = entry.get("owner") as Entity
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		active_entries.erase(effect_key)
		return

	var damage_callback = Callable(self, "_on_owner_damage_taken").bind(effect_key)
	entry["damage_callback"] = damage_callback
	entry["battle_callback"] = Callable()
	active_entries[effect_key] = entry

	if not owner.damage_taken.is_connected(damage_callback):
		owner.damage_taken.connect(damage_callback)


func _on_owner_damage_taken(damage_data: DamageData, effect_key: String) -> void:
	if not _can_trigger(damage_data, effect_key):
		return

	var entry = active_entries[effect_key] as Dictionary
	entry["triggered"] = true
	active_entries[effect_key] = entry
	_disconnect_damage_listener(effect_key)

	var relic_context = entry.get("relic_context") as RelicContext
	var owner = entry.get("owner") as Entity
	_spawn_pets(owner, relic_context, effect_key)


func _can_trigger(damage_data: DamageData, effect_key: String) -> bool:
	if not active_entries.has(effect_key):
		return false
	if damage_data == null:
		return false
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return false

	var entry = active_entries[effect_key] as Dictionary
	if bool(entry.get("triggered", false)):
		return false

	var owner = entry.get("owner") as Entity
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		return false
	if damage_data.target != owner:
		return false
	return true


func _spawn_pets(owner: Entity, relic_context: RelicContext, effect_key: String) -> void:
	if owner == null or relic_context == null:
		return

	var count = _get_summon_count(relic_context)
	if count <= 0:
		return

	var parent = _resolve_spawn_parent(owner)
	if parent == null:
		return

	active_pets[effect_key] = []
	for offset in _build_spawn_offsets(count):
		_spawn_one_pet(parent, owner, owner.global_position + offset, relic_context, effect_key)


func _spawn_one_pet(parent: Node, summoner: Entity, spawn_position: Vector2, relic_context: RelicContext, effect_key: String) -> void:
	var node = pet_scene.instantiate() as Node2D
	if node == null:
		return

	var pet = node as SummonPet
	_prepare_pet_before_ready(node, pet, relic_context)
	parent.add_child(node)
	node.global_position = spawn_position

	if pet != null:
		pet.set_summoner(summoner)
		if play_spawn_animation:
			pet.call_deferred("play_spawn_animation", spawn_animation_name)

	var pets = active_pets.get(effect_key, []) as Array
	pets.append(node)
	active_pets[effect_key] = pets


func _prepare_pet_before_ready(node: Node2D, pet: SummonPet, relic_context: RelicContext) -> void:
	var stats_controller = node.get_node_or_null("StatsController") as StatsController
	var stats_data = _get_pet_stats(relic_context)
	if stats_controller != null and stats_data != null:
		stats_controller.stats_data = stats_data

	if pet != null:
		pet.ability_select_mode = _get_pet_ability_select_mode(relic_context)


func _get_summon_count(relic_context: RelicContext) -> int:
	var result = max(summon_count, 0)
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		result += max(levelup_extra_count, 0)
	return result


func _get_pet_stats(relic_context: RelicContext) -> StatsData:
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_pet_stats != null:
		return levelup_pet_stats
	return normal_pet_stats


func _get_pet_ability_select_mode(relic_context: RelicContext) -> SummonPet.AbilitySelectMode:
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return levelup_ability_select_mode
	return normal_ability_select_mode


func _build_spawn_offsets(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var safe_count = max(count, 1)
	var safe_radius = max(spawn_radius, min_spawn_distance)
	var base_angle = randf() * TAU if random_angle_offset else 0.0

	for index in range(safe_count):
		var angle = base_angle + TAU * float(index) / float(safe_count)
		var distance = randf_range(min_spawn_distance, safe_radius)
		result.append(Vector2.RIGHT.rotated(angle) * distance)

	return result


func _resolve_spawn_parent(owner: Entity) -> Node:
	if spawn_parent_path != NodePath():
		var from_owner = owner.get_node_or_null(spawn_parent_path)
		if from_owner != null:
			return from_owner

		var current_scene = owner.get_tree().current_scene
		if current_scene != null:
			var from_scene = current_scene.get_node_or_null(spawn_parent_path)
			if from_scene != null:
				return from_scene

	if owner.get_parent() != null:
		return owner.get_parent()

	var tree = owner.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


func _disconnect_entry(effect_key: String) -> void:
	if not active_entries.has(effect_key):
		return

	var entry = active_entries[effect_key] as Dictionary
	var battle_callback = entry.get("battle_callback") as Callable
	if battle_callback.is_valid() and EventBus.battle_started.is_connected(battle_callback):
		EventBus.battle_started.disconnect(battle_callback)

	_disconnect_damage_listener(effect_key)
	active_entries.erase(effect_key)


func _disconnect_damage_listener(effect_key: String) -> void:
	if not active_entries.has(effect_key):
		return

	var entry = active_entries[effect_key] as Dictionary
	var owner = entry.get("owner") as Entity
	var damage_callback = entry.get("damage_callback") as Callable
	if owner != null and is_instance_valid(owner) and damage_callback.is_valid() and owner.damage_taken.is_connected(damage_callback):
		owner.damage_taken.disconnect(damage_callback)

	entry["damage_callback"] = Callable()
	active_entries[effect_key] = entry


func _clear_spawned_pets(effect_key: String) -> void:
	var pets = active_pets.get(effect_key, []) as Array
	for pet in pets:
		if not is_instance_valid(pet):
			continue

		var pet_node = pet as Node
		if pet_node != null:
			pet_node.queue_free()
	active_pets.erase(effect_key)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
