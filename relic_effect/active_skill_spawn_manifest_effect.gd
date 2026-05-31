## 技能释放后生成 Manifest 的通用遗物效果。
## 通过“栏位过滤 + 内部冷却 + Manifest 属性覆盖”，可复用给大剑横扫、额外飞刀、额外法球等效果。
class_name ActiveSkillSpawnManifestEffect
extends RelicEffect


enum TargetMode {
	## 朝鼠标位置生成，适合玩家装备。
	MOUSE_POSITION,
	## 朝角色当前面向生成，适合无鼠标目标的实体。
	FACING_DIRECTION,
}


## 触发时生成的 Manifest 场景。为空时不会注册效果，方便先在资源里占位，之后补动画场景。
@export var manifest_scene: PackedScene
## 为空时所有技能都能触发；填 [0] 时只允许基础攻击触发。
@export var target_slot_indices: Array[int] = []
## 这些技能栏位不会触发。适合排除基础攻击或某些特殊技能。
@export var excluded_slot_indices: Array[int] = []
## 每次技能释放后的触发概率。
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.25
## 触发后的内部冷却。大于 0 时，冷却结束前不会再次生成 Manifest。
@export var trigger_cooldown: float = 0.0
## 普通状态生成数量。
@export var spawn_count: int = 1
## 升级态生成数量。小于等于 0 时沿用 spawn_count。
@export var levelup_spawn_count: int = 0
## 多个 Manifest 的扇形散布角度。
@export var spread_angle_degrees: float = 12.0
## 目标方向计算方式。
@export var target_mode: TargetMode = TargetMode.MOUSE_POSITION
## 生成位置偏移，通常用于让投射物从角色前方出现。
@export var spawn_offset: Vector2 = Vector2.ZERO
## 是否让 Manifest 朝生成方向旋转。
@export var rotate_to_direction: bool = true
## 普通状态下写入 Manifest 的属性覆盖。
@export var manifest_property_overrides: Dictionary = {}
## 升级态额外写入 Manifest 的属性覆盖。
@export var levelup_manifest_property_overrides: Dictionary = {}

var active_connections: Dictionary = {}
var cooldown_until_times: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null or manifest_scene == null:
		return

	var ability_controller := owner.get_node_or_null("AbilityController")
	if ability_controller == null or not ability_controller.has_signal("ability_triggered"):
		return

	var key := str(effect_key)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_ability_triggered").bind(relic_context, key)
	ability_controller.connect(&"ability_triggered", callback)
	active_connections[key] = {
		"controller": ability_controller,
		"callback": callback,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_connections.has(key):
		return

	var entry := active_connections[key] as Dictionary
	var controller := entry.get("controller") as Node
	var callback := entry.get("callback") as Callable
	if controller != null and is_instance_valid(controller) and controller.is_connected(&"ability_triggered", callback):
		controller.disconnect(&"ability_triggered", callback)

	active_connections.erase(key)
	cooldown_until_times.erase(key)


func _on_ability_triggered(ability: Ability, caster: Entity, relic_context: RelicContext, effect_key: String) -> void:
	if caster == null or relic_context == null or caster != relic_context.owner:
		return
	if caster.is_dead or randf() > trigger_chance:
		return
	if not _ability_matches(ability):
		return
	if _is_on_cooldown(effect_key):
		return

	var direction := _get_target_direction(caster)
	if direction == Vector2.ZERO:
		return

	_mark_cooldown(effect_key)
	var count := _get_spawn_count(relic_context)
	var directions := _build_spread_directions(direction, count)
	for spawn_direction in directions:
		_spawn_manifest(caster, ability, spawn_direction, relic_context)


func _spawn_manifest(caster: Entity, ability: Ability, direction: Vector2, relic_context: RelicContext) -> void:
	var manifest := manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var spawn_position := caster.global_position + spawn_offset.rotated(direction.angle())
	_add_manifest_to_scene(caster, manifest, spawn_position)
	if rotate_to_direction:
		manifest.global_rotation = direction.angle()

	_apply_property_overrides(manifest, manifest_property_overrides)
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		_apply_property_overrides(manifest, levelup_manifest_property_overrides)

	var context := AbilityContext.new(caster, ability)
	context.targets.append(spawn_position + direction.normalized() * 120.0)
	context.locked_direction = direction.normalized()
	manifest.activate(context)


func _get_spawn_count(relic_context: RelicContext) -> int:
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_spawn_count > 0:
		return max(levelup_spawn_count, 1)
	return max(spawn_count, 1)


func _get_target_direction(caster: Entity) -> Vector2:
	match target_mode:
		TargetMode.MOUSE_POSITION:
			return (caster.get_global_mouse_position() - caster.global_position).normalized()

	var direction := caster.get_facing_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return direction.normalized()


func _build_spread_directions(base_direction: Vector2, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 1:
		result.append(base_direction.normalized())
		return result

	var total_angle := deg_to_rad(spread_angle_degrees)
	for index in range(count):
		var ratio := 0.0 if count == 1 else float(index) / float(count - 1)
		var angle = lerp(-total_angle * 0.5, total_angle * 0.5, ratio)
		result.append(base_direction.rotated(angle).normalized())
	return result


func _ability_matches(ability: Ability) -> bool:
	if ability == null:
		return false
	if not target_slot_indices.is_empty() and not target_slot_indices.has(ability.runtime_slot_index):
		return false
	if excluded_slot_indices.has(ability.runtime_slot_index):
		return false
	return true


func _is_on_cooldown(effect_key: String) -> bool:
	if trigger_cooldown <= 0.0:
		return false
	var end_time := int(cooldown_until_times.get(effect_key, 0))
	return Time.get_ticks_msec() < end_time


func _mark_cooldown(effect_key: String) -> void:
	if trigger_cooldown <= 0.0:
		return
	cooldown_until_times[effect_key] = Time.get_ticks_msec() + int(trigger_cooldown * 1000.0)


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
