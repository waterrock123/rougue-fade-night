## 消耗品使用时生成 AbilityManifest 的通用效果。
## 适合复用给石头、飞刀、炸弹、药瓶等“使用后像技能一样生成实体”的消耗品。
class_name UseSpawnManifestEffect
extends RelicEffect


## Manifest 的瞄准方式。
enum TargetMode {
	## 朝鼠标所在世界坐标发射，最适合玩家主动使用的投掷物。
	MOUSE_POSITION,
	## 朝拥有者当前面朝方向发射。
	FACING_DIRECTION,
	## 朝指定 group 内最近的目标发射，找不到目标时回退到面朝方向。
	NEAREST_GROUP,
}


## 使用时要生成的 AbilityManifest 场景。
@export var manifest_scene: PackedScene
## 目标点计算方式。
@export var target_mode: TargetMode = TargetMode.MOUSE_POSITION
## target_mode 为 NEAREST_GROUP 时搜索的目标组名。
@export var target_group: String = "enemy"
## 最近目标的最大搜索距离。小于等于 0 时不限制距离。
@export var max_target_distance: float = 600.0
## 是否把 Manifest 挂成使用者子节点。投射物通常建议关闭，直接挂到当前场景。
@export var set_as_child: bool = false
## 生成位置偏移。
@export var spawn_offset: Vector2 = Vector2.ZERO
## 是否根据目标方向旋转 Manifest。
@export var rotate_to_direction: bool = true
## 生成后缩放倍率，方便同一个 Manifest 做大小变体。
@export var scale_multiplier: float = 1.0
## 普通状态下覆盖 Manifest 属性。示例：{"damage": 50.0}。
@export var manifest_property_overrides: Dictionary = {}
## 遗物处于升级态时额外覆盖 Manifest 属性。示例：{"damage": 80.0}。
@export var levelup_manifest_property_overrides: Dictionary = {}


## 使用消耗品时生成 Manifest，并伪造一个 AbilityContext 供现有投射物/命中逻辑复用。
func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or manifest_scene == null:
		return
	if not (relic_context.owner is Entity):
		return

	var caster := relic_context.owner as Entity
	if caster.is_dead:
		return

	var manifest := manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var target_position := _get_target_position(caster)
	if target_position.distance_squared_to(caster.global_position) <= 0.001:
		var fallback_direction := caster.get_facing_direction()
		if fallback_direction == Vector2.ZERO:
			fallback_direction = Vector2.RIGHT
		target_position = caster.global_position + fallback_direction.normalized() * 100.0

	var direction := (target_position - caster.global_position).normalized()
	var spawn_position := caster.global_position + spawn_offset

	_add_manifest_to_scene(caster, manifest, spawn_position)
	if rotate_to_direction and direction != Vector2.ZERO:
		manifest.global_rotation = direction.angle()
	manifest.scale *= scale_multiplier

	if manifest is ProjectileManifest:
		(manifest as ProjectileManifest).source = caster

	_apply_property_overrides(manifest, manifest_property_overrides)
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		_apply_property_overrides(manifest, levelup_manifest_property_overrides)

	var context := AbilityContext.new(caster, null)
	context.targets.append(target_position)
	manifest.activate(context)


func _add_manifest_to_scene(caster: Entity, manifest: AbilityManifest, spawn_position: Vector2) -> void:
	if set_as_child:
		caster.add_child(manifest)
		manifest.global_position = spawn_position
		return

	var root := caster.get_tree().current_scene
	if root == null:
		root = caster.get_tree().root
	root.add_child(manifest)
	manifest.global_position = spawn_position


func _get_target_position(caster: Entity) -> Vector2:
	match target_mode:
		TargetMode.MOUSE_POSITION:
			return caster.get_global_mouse_position()
		TargetMode.NEAREST_GROUP:
			var target := _find_nearest_target(caster)
			if target != null:
				return target.global_position

	var direction := caster.get_facing_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return caster.global_position + direction.normalized() * 100.0


func _find_nearest_target(caster: Entity) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF

	for node in caster.get_tree().get_nodes_in_group(target_group):
		if not (node is Node2D):
			continue
		if node == caster:
			continue
		if node is Entity:
			var entity := node as Entity
			if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
				continue

		var distance := caster.global_position.distance_to((node as Node2D).global_position)
		if max_target_distance > 0.0 and distance > max_target_distance:
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = node as Node2D

	return nearest


func _apply_property_overrides(manifest: AbilityManifest, overrides: Dictionary) -> void:
	for property_name in overrides.keys():
		manifest.set(StringName(property_name), overrides[property_name])
