## 释放指定技能时积攒 Manifest，释放指定技能时再把积攒的 Manifest 打出去。
## 投斧套装使用它实现“悬浮投斧叠层 -> 普攻释放投斧”。
class_name AbilityCastBankManifestEffect
extends RelicEffect

enum ReleaseMode {
	ONE_BY_ONE,
	ALL_AT_ONCE,
}

@export_group("积攒与释放")
@export var manifest_scene: PackedScene
@export var stack_icon: Texture2D
@export var charge_excluded_slot_indices: Array[int] = [0]
@export var release_slot_indices: Array[int] = [0]
@export var max_stacks: int = 8
@export var release_mode: ReleaseMode = ReleaseMode.ONE_BY_ONE
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var target_distance: float = 120.0
@export var rotate_to_direction: bool = true
@export var multi_release_spacing: float = 6.0
@export var levelup_manifest_property_overrides: Dictionary = {}

@export_group("悬浮视觉")
@export var visual_base_offset: Vector2 = Vector2(0.0, -30.0)
@export var visual_stack_offset: Vector2 = Vector2(5.5, -2.0)
@export var visual_scale: Vector2 = Vector2(0.45, 0.45)
@export var visual_rotation_step: float = 0.12
@export var visual_z_index: int = 120
@export var visual_follow_strength: float = 18.0
@export var visual_damping: float = 10.0
@export var visual_sway_amplitude: float = 3.5
@export var visual_sway_speed: float = 2.2
@export var visual_rotation_sway: float = 0.07

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or manifest_scene == null:
		return

	var ability_controller: AbilityController = owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var key: String = str(effect_key)
	if active_entries.has(key):
		return

	var callback: Callable = Callable(self, "_on_ability_triggered").bind(relic_context, key)
	if not ability_controller.ability_triggered.is_connected(callback):
		ability_controller.ability_triggered.connect(callback)

	active_entries[key] = {
		"owner": owner,
		"controller": ability_controller,
		"callback": callback,
		"stacks": 0,
		"visuals": [],
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_entries.has(key):
		return

	var entry: Dictionary = active_entries[key] as Dictionary
	var controller: AbilityController = entry.get("controller") as AbilityController
	var callback: Callable = entry.get("callback") as Callable
	if controller != null and is_instance_valid(controller) and controller.ability_triggered.is_connected(callback):
		controller.ability_triggered.disconnect(callback)

	_clear_visuals(entry)
	active_entries.erase(key)


func _on_ability_triggered(ability: Ability, caster: Entity, relic_context: RelicContext, effect_key: String) -> void:
	if ability == null or caster == null or relic_context == null or caster != relic_context.owner:
		return
	if not active_entries.has(effect_key):
		return

	if release_slot_indices.has(ability.runtime_slot_index):
		_release_banked_manifests(caster, ability, relic_context, effect_key)
		return

	if not charge_excluded_slot_indices.has(ability.runtime_slot_index):
		_add_stack(caster, effect_key)


func _add_stack(owner: Entity, effect_key: String) -> void:
	var entry: Dictionary = active_entries[effect_key] as Dictionary
	var current_stacks: int = int(entry.get("stacks", 0))
	var stacks: int = min(current_stacks + 1, max(max_stacks, 1))
	entry["stacks"] = stacks
	active_entries[effect_key] = entry
	_refresh_visuals(owner, effect_key)


func _release_banked_manifests(caster: Entity, ability: Ability, relic_context: RelicContext, effect_key: String) -> void:
	var entry: Dictionary = active_entries[effect_key] as Dictionary
	var stacks: int = int(entry.get("stacks", 0))
	if stacks <= 0:
		return

	var direction: Vector2 = _get_release_direction(caster)
	if direction == Vector2.ZERO:
		return

	var release_count: int = 1
	if release_mode == ReleaseMode.ALL_AT_ONCE:
		release_count = stacks

	entry["stacks"] = max(stacks - release_count, 0)
	active_entries[effect_key] = entry
	_refresh_visuals(caster, effect_key)

	for index in range(release_count):
		_release_one_manifest(caster, ability, relic_context, direction, index, release_count)


func _release_one_manifest(
	caster: Entity,
	ability: Ability,
	relic_context: RelicContext,
	direction: Vector2,
	release_index: int,
	release_count: int
) -> void:
	var manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var perpendicular: Vector2 = direction.orthogonal()
	var centered_index: float = float(release_index) - float(release_count - 1) * 0.5
	var spread_offset: Vector2 = perpendicular * centered_index * multi_release_spacing
	var spawn_position: Vector2 = caster.global_position + spawn_offset.rotated(direction.angle()) + spread_offset

	_add_manifest_to_scene(caster, manifest, spawn_position)
	if rotate_to_direction:
		manifest.global_rotation = direction.angle()
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		_apply_property_overrides(manifest, levelup_manifest_property_overrides)

	var context: AbilityContext = AbilityContext.new(caster, ability)
	context.targets.append(caster.global_position + direction * target_distance)
	context.locked_direction = direction
	manifest.activate(context)


func _refresh_visuals(owner: Entity, effect_key: String) -> void:
	var entry: Dictionary = active_entries[effect_key] as Dictionary
	_clear_visuals(entry)
	if stack_icon == null:
		return

	var root: Node = _get_scene_root(owner)
	if root == null:
		return

	var visuals: Array[Node] = []
	var stacks: int = int(entry.get("stacks", 0))
	for index in range(stacks):
		var visual: FloatingBankVisual = FloatingBankVisual.new()
		var centered_index: float = float(index) - float(stacks - 1) * 0.5
		var target_offset: Vector2 = visual_base_offset + visual_stack_offset * centered_index
		var base_rotation: float = centered_index * visual_rotation_step
		root.add_child(visual)
		visual.setup(
			owner,
			stack_icon,
			visual_scale,
			target_offset,
			base_rotation,
			float(index) * 0.45,
			visual_z_index + index,
			visual_follow_strength,
			visual_damping,
			visual_sway_amplitude,
			visual_sway_speed,
			visual_rotation_sway
		)
		visuals.append(visual)

	entry["visuals"] = visuals
	active_entries[effect_key] = entry


func _clear_visuals(entry: Dictionary) -> void:
	var visuals: Array = entry.get("visuals", [])
	for visual in visuals:
		if visual != null and is_instance_valid(visual):
			(visual as Node).queue_free()
	entry["visuals"] = []


func _get_release_direction(caster: Entity) -> Vector2:
	var mouse_direction: Vector2 = caster.get_global_mouse_position() - caster.global_position
	if mouse_direction.length_squared() > 0.001:
		return mouse_direction.normalized()

	var facing: Vector2 = caster.get_facing_direction()
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	return facing.normalized()


func _add_manifest_to_scene(caster: Entity, manifest: AbilityManifest, spawn_position: Vector2) -> void:
	var root: Node = _get_scene_root(caster)
	if root == null:
		return
	root.add_child(manifest)
	manifest.global_position = spawn_position


func _get_scene_root(owner: Node) -> Node:
	if owner == null or owner.get_tree() == null:
		return null

	var root: Node = owner.get_tree().current_scene
	if root == null:
		root = owner.get_tree().root
	return root


func _apply_property_overrides(manifest: AbilityManifest, overrides: Dictionary) -> void:
	for property_name in overrides.keys():
		manifest.set(StringName(property_name), overrides[property_name])


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
