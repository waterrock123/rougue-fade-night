## 遗物效果：战斗中按固定间隔向四周释放多个 Manifest。
## 适合“自动发射追踪孢子”“环绕法球”“周期性散射弹幕”等装备效果。
class_name PeriodicRadialManifestEffect
extends RelicEffect

@export_group("触发")
@export var interval: float = 4.0
@export var initial_delay: float = 1.0
@export var trigger_immediately_on_battle_start: bool = false

@export_group("Manifest")
@export var manifest_scene: PackedScene
@export_range(1, 48, 1) var manifest_count: int = 4
@export_range(0, 48, 1) var levelup_manifest_count: int = 0
@export var target_distance: float = 280.0
@export var spawn_radius: float = 14.0
@export var start_angle_degrees: float = 0.0
@export var randomize_start_angle: bool = true
@export_range(0.0, 45.0, 0.5) var angle_jitter_degrees: float = 8.0
@export var rotate_to_direction: bool = true
@export var manifest_property_overrides: Dictionary = {}
@export var levelup_manifest_property_overrides: Dictionary = {}

@export_group("伤害")
@export var base_damage: float = 10.0
@export var stat_name: StringName = &"intelligence"
@export var stat_multiplier: float = 1.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.POISON, DamageData.DamageType.RANGED]
@export var tags: Array[String] = ["relic", "spore", "projectile", "ranged", "poison"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
@export var target_group: StringName = &"enemy"

var active_entries: Dictionary = {}
var activation_serial: int = 0


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or manifest_scene == null:
		return

	var key: String = str(effect_key)
	if active_entries.has(key):
		return

	# 每次激活都分配新的代次，避免旧的异步循环在重新激活后误用新状态。
	activation_serial += 1
	var generation: int = activation_serial
	var callback: Callable = Callable(self, "_on_battle_started").bind(key, generation)
	active_entries[key] = {
		"owner": owner,
		"context": relic_context,
		"callback": callback,
		"active": true,
		"loop_running": false,
		"generation": generation,
	}

	if not EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.connect(callback)
	if EventBus.is_battle_active:
		_start_loop(key, generation)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_entries.has(key):
		return

	var entry: Dictionary = active_entries[key] as Dictionary
	entry["active"] = false

	var callback: Callable = entry.get("callback") as Callable
	if callback.is_valid() and EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)

	active_entries.erase(key)


func _on_battle_started(key: String, generation: int) -> void:
	_start_loop(key, generation)


func _start_loop(key: String, generation: int) -> void:
	if not _is_entry_current(key, generation):
		return

	var entry: Dictionary = active_entries[key] as Dictionary
	if bool(entry.get("loop_running", false)):
		return

	entry["loop_running"] = true
	active_entries[key] = entry
	_spawn_loop.call_deferred(key, generation)


func _spawn_loop(key: String, generation: int) -> void:
	if not _is_entry_current(key, generation):
		return

	if trigger_immediately_on_battle_start:
		_try_spawn_barrage(key, generation)

	var first_wait: float = max(initial_delay, 0.0)
	if first_wait > 0.0:
		if not await _wait_owner_timer(key, generation, first_wait):
			_finish_loop(key, generation)
			return

	while _is_entry_current(key, generation):
		_try_spawn_barrage(key, generation)
		if not await _wait_owner_timer(key, generation, max(interval, 0.05)):
			break

	_finish_loop(key, generation)


func _wait_owner_timer(key: String, generation: int, wait_time: float) -> bool:
	if not _is_entry_current(key, generation):
		return false

	var owner: Entity = (active_entries[key] as Dictionary).get("owner") as Entity
	if not _is_owner_valid(owner):
		return false

	await owner.get_tree().create_timer(wait_time).timeout
	return _is_entry_current(key, generation) and _is_owner_valid(owner)


func _try_spawn_barrage(key: String, generation: int) -> void:
	if not _is_entry_current(key, generation) or not EventBus.is_battle_active:
		return

	var entry: Dictionary = active_entries[key] as Dictionary
	if not bool(entry.get("active", false)):
		return

	var owner: Entity = entry.get("owner") as Entity
	var relic_context: RelicContext = entry.get("context") as RelicContext
	if not _is_owner_valid(owner) or relic_context == null:
		return

	var directions: Array[Vector2] = _build_radial_directions(_get_manifest_count(relic_context))
	for direction in directions:
		_spawn_one_manifest(owner, direction, relic_context)


func _spawn_one_manifest(owner: Entity, direction: Vector2, relic_context: RelicContext) -> void:
	var manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var spawn_position: Vector2 = owner.global_position + direction * spawn_radius
	var root: Node = _get_scene_root(owner)
	if root == null:
		manifest.queue_free()
		return

	root.add_child(manifest)
	manifest.global_position = spawn_position
	if rotate_to_direction and direction != Vector2.ZERO:
		manifest.global_rotation = direction.angle()

	_apply_manifest_runtime_properties(manifest, owner, relic_context)

	var context: AbilityContext = AbilityContext.new(owner, null)
	context.locked_direction = direction.normalized()
	context.targets = [spawn_position + direction.normalized() * target_distance]
	manifest.activate(context)


func _apply_manifest_runtime_properties(manifest: AbilityManifest, owner: Entity, relic_context: RelicContext) -> void:
	var damage: float = base_damage + _get_owner_stat(owner) * stat_multiplier
	manifest.set(&"damage", damage)
	manifest.set(&"can_crit", can_crit)
	manifest.set(&"damage_types", damage_types.duplicate())
	manifest.set(&"tags", tags.duplicate())
	manifest.set(&"target_group", target_group)
	manifest.set(&"scaling_rule", scaling_rule)

	_apply_property_overrides(manifest, manifest_property_overrides)
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		_apply_property_overrides(manifest, levelup_manifest_property_overrides)


func _build_radial_directions(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var safe_count: int = max(count, 1)
	var start_angle: float = deg_to_rad(start_angle_degrees)
	if randomize_start_angle:
		start_angle += randf() * TAU

	for index in range(safe_count):
		var angle: float = start_angle + TAU * float(index) / float(safe_count)
		if angle_jitter_degrees > 0.0:
			angle += deg_to_rad(randf_range(-angle_jitter_degrees, angle_jitter_degrees))
		result.append(Vector2.RIGHT.rotated(angle).normalized())

	return result


func _get_manifest_count(relic_context: RelicContext) -> int:
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_manifest_count > 0:
		return levelup_manifest_count
	return manifest_count


func _get_owner_stat(owner: Entity) -> float:
	if owner == null or owner.stats_controller == null:
		return 0.0
	return owner.stats_controller.get_stat(stat_name)


func _apply_property_overrides(manifest: AbilityManifest, overrides: Dictionary) -> void:
	for property_name in overrides.keys():
		manifest.set(StringName(property_name), overrides[property_name])


func _finish_loop(key: String, generation: int) -> void:
	if not _is_entry_current(key, generation):
		return

	var entry: Dictionary = active_entries[key] as Dictionary
	entry["loop_running"] = false
	active_entries[key] = entry


func _is_entry_current(key: String, generation: int) -> bool:
	if not active_entries.has(key):
		return false

	var entry: Dictionary = active_entries[key] as Dictionary
	return bool(entry.get("active", false)) and int(entry.get("generation", -1)) == generation


func _is_owner_valid(owner: Entity) -> bool:
	return owner != null and is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_dead


func _get_scene_root(owner: Node) -> Node:
	if owner == null or owner.get_tree() == null:
		return null

	var root: Node = owner.get_tree().current_scene
	if root == null:
		root = owner.get_tree().root
	return root


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
