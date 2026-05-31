## 释放非基础技能时积攒 Manifest，释放基础攻击时消耗一层并朝攻击方向发射。
## 投斧套装使用它实现“悬浮投斧叠层 -> 普攻释放投斧”。
class_name AbilityCastBankManifestEffect
extends RelicEffect

@export var manifest_scene: PackedScene
@export var stack_icon: Texture2D
@export var charge_excluded_slot_indices: Array[int] = [0]
@export var release_slot_indices: Array[int] = [0]
@export var max_stacks: int = 8
@export var visual_radius: float = 18.0
@export var visual_scale: Vector2 = Vector2(0.45, 0.45)
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var target_distance: float = 120.0
@export var rotate_to_direction: bool = true
@export var levelup_manifest_property_overrides: Dictionary = {}

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null or manifest_scene == null:
		return

	var ability_controller := owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var key := str(effect_key)
	if active_entries.has(key):
		return

	var callback := Callable(self, "_on_ability_triggered").bind(relic_context, key)
	ability_controller.ability_triggered.connect(callback)
	active_entries[key] = {
		"owner": owner,
		"controller": ability_controller,
		"callback": callback,
		"stacks": 0,
		"visuals": [],
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_entries.has(key):
		return

	var entry := active_entries[key] as Dictionary
	var controller := entry.get("controller") as AbilityController
	var callback := entry.get("callback") as Callable
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
		_release_one_manifest(caster, ability, relic_context, effect_key)
		return

	if not charge_excluded_slot_indices.has(ability.runtime_slot_index):
		_add_stack(caster, effect_key)


func _add_stack(owner: Entity, effect_key: String) -> void:
	var entry := active_entries[effect_key] as Dictionary
	var stacks = min(int(entry.get("stacks", 0)) + 1, max(max_stacks, 1))
	entry["stacks"] = stacks
	active_entries[effect_key] = entry
	_refresh_visuals(owner, effect_key)


func _release_one_manifest(caster: Entity, ability: Ability, relic_context: RelicContext, effect_key: String) -> void:
	var entry := active_entries[effect_key] as Dictionary
	if int(entry.get("stacks", 0)) <= 0:
		return

	entry["stacks"] = int(entry.get("stacks", 0)) - 1
	active_entries[effect_key] = entry
	_refresh_visuals(caster, effect_key)

	var direction := _get_release_direction(caster)
	if direction == Vector2.ZERO:
		return

	var manifest := manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	_add_manifest_to_scene(caster, manifest, caster.global_position + spawn_offset.rotated(direction.angle()))
	if rotate_to_direction:
		manifest.global_rotation = direction.angle()
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		_apply_property_overrides(manifest, levelup_manifest_property_overrides)

	var context := AbilityContext.new(caster, ability)
	context.targets.append(caster.global_position + direction * target_distance)
	context.locked_direction = direction
	manifest.activate(context)


func _refresh_visuals(owner: Entity, effect_key: String) -> void:
	var entry := active_entries[effect_key] as Dictionary
	_clear_visuals(entry)
	if stack_icon == null:
		return

	var visuals: Array[Node] = []
	var stacks := int(entry.get("stacks", 0))
	for index in range(stacks):
		var sprite := Sprite2D.new()
		sprite.texture = stack_icon
		sprite.scale = visual_scale
		sprite.z_index = 120
		var angle := TAU * float(index) / float(max(stacks, 1))
		sprite.position = Vector2(cos(angle), sin(angle)) * visual_radius
		owner.add_child(sprite)
		visuals.append(sprite)

	entry["visuals"] = visuals
	active_entries[effect_key] = entry


func _clear_visuals(entry: Dictionary) -> void:
	var visuals: Array = entry.get("visuals", [])
	for visual in visuals:
		if visual != null and is_instance_valid(visual):
			(visual as Node).queue_free()
	entry["visuals"] = []


func _get_release_direction(caster: Entity) -> Vector2:
	var mouse_direction := caster.get_global_mouse_position() - caster.global_position
	if mouse_direction.length_squared() > 0.001:
		return mouse_direction.normalized()

	var facing := caster.get_facing_direction()
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	return facing.normalized()


func _add_manifest_to_scene(caster: Entity, manifest: AbilityManifest, spawn_position: Vector2) -> void:
	var root := caster.get_tree().current_scene
	if root == null:
		root = caster.get_tree().root
	root.add_child(manifest)
	manifest.global_position = spawn_position


func _apply_property_overrides(manifest: AbilityManifest, overrides: Dictionary) -> void:
	for property_name in overrides.keys():
		manifest.set(StringName(property_name), overrides[property_name])


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
