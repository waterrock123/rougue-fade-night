class_name ProjectileManifest
extends AbilityManifest

@export_group("Projectile")
@export var speed: float = 10.0
@export var target_group: String
@export var max_distance: float = 1000.0
@export var is_rotate: bool = false
@export var hit_sound: AudiioConfig
@export var rotate_speed: float = 10.0

@export_group("Return")
@export var return_to_source_after_max_distance: bool = false
@export var return_speed_multiplier: float = 1.0
@export var return_arrive_distance: float = 18.0
@export var return_max_distance_multiplier: float = 1.0

@export_group("Damage")
@export var damage: float = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.RANGED]
@export var tags: Array[String] = ["manifest", "projectile", "ranged"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
@export var is_penetrate: bool = false

@onready var sprite2d: Sprite2D = $Sprite2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var current_dir: Vector2 = Vector2.ZERO
var current_distance: float = 0.0
var return_distance: float = 0.0
var is_returning: bool = false


# 初始化投射物飞行方向、来源和距离修正。
func activate(context: AbilityContext) -> void:
	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1
	_apply_projectile_range_bonus()
	if not EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.connect(_handle_game_pause)
	if not EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.connect(_handle_scene_changed)

	if context.targets.size() > 0:
		var target_pos: Vector2 = context.get_target_positon(0)
		if target_pos != global_position:
			current_dir = (target_pos - global_position).normalized()
			look_at(target_pos)
	elif context.locked_direction != Vector2.ZERO:
		current_dir = context.locked_direction.normalized()


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.disconnect(_handle_game_pause)
	if EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.disconnect(_handle_scene_changed)


# 推进投射物。可选回旋逻辑会在达到最远距离后沿直线追向施法者。
func _process(delta: float) -> void:
	if source != null and not is_instance_valid(source):
		queue_free()
		return
	if source != null and source.is_dead:
		queue_free()
		return

	if is_returning:
		_process_returning(delta)
	else:
		_process_forward(delta)

	if is_rotate:
		global_rotation += delta * rotate_speed


func _process_forward(delta: float) -> void:
	if current_dir == Vector2.ZERO:
		queue_free()
		return

	var movement: Vector2 = current_dir * delta * speed
	current_distance += movement.length()
	global_position += movement

	if current_distance >= max_distance:
		if return_to_source_after_max_distance:
			_begin_returning()
		else:
			queue_free()


func _process_returning(delta: float) -> void:
	var valid_source: Entity = _get_valid_source()
	if valid_source == null:
		queue_free()
		return

	var to_source: Vector2 = valid_source.global_position - global_position
	var distance_to_source: float = to_source.length()
	if distance_to_source <= return_arrive_distance:
		queue_free()
		return

	current_dir = to_source.normalized()
	var movement_length: float = delta * speed * max(return_speed_multiplier, 0.01)
	if movement_length >= distance_to_source:
		queue_free()
		return

	var movement: Vector2 = current_dir * movement_length
	return_distance += movement.length()
	global_position += movement

	# 如果玩家移动太快，投斧不会无限追踪；回旋路程用完后直接消失。
	var allowed_return_distance: float = max_distance * max(return_max_distance_multiplier, 0.01)
	if return_distance >= allowed_return_distance:
		queue_free()


func _begin_returning() -> void:
	is_returning = true
	return_distance = 0.0
	current_distance = max_distance


# 跟随全局暂停状态处理贴图动画暂停。
func _handle_game_pause(pause: bool) -> void:
	if sprite2d != null and sprite2d.texture is AnimatedTexture:
		(sprite2d.texture as AnimatedTexture).pause = pause


# 切回 home 场景时清理残留投射物。
func _handle_scene_changed(scene: String) -> void:
	if scene == "home":
		queue_free()


# 命中目标时创建 DamageData，并交给实体统一受伤链路处理。
func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent == null or not _matches_target_group(parent):
		return

	if parent is Entity:
		if parent.has_method("can_be_targeted") and not parent.can_be_targeted():
			return

		var valid_source: Entity = _get_valid_source()
		if source != null and valid_source == null:
			queue_free()
			return

		var damage_data: DamageData = DamageData.create(
			damage,
			damage_types,
			tags,
			valid_source,
			parent,
			can_crit,
			scaling_rule,
			source_ability_id,
			source_ability_slot_index
		)
		parent.apply_damage(damage_data)

		if hit_sound != null:
			AudioController.play(hit_sound, global_position)

		if is_penetrate:
			return

		queue_free()


func _get_valid_source() -> Entity:
	# 投射物可能比施法者活得更久；旧引用失效时不能再传给 DamageData。
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source


func _matches_target_group(node: Node) -> bool:
	if target_group.is_empty():
		return true
	if node is Entity:
		return (node as Entity).matches_target_group(StringName(target_group))
	return node.is_in_group(target_group)


func _apply_projectile_range_bonus() -> void:
	if source == null or source.stats_controller == null:
		return

	var bonus_rate: float = max(source.stats_controller.get_stat(&"projectile_range_bonus_rate"), 0.0)
	if bonus_rate <= 0.0:
		return
	if not tags.has("projectile"):
		return

	# 只对 projectile 标签的 manifest 生效，抛射物、近战特效等不会被投射物增程误影响。
	max_distance *= 1.0 + bonus_rate
