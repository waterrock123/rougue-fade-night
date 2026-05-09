class_name ProjectileManifest
extends AbilityManifest

@export_group("Projectile")
@export var speed = 10.0
@export var target_group: String
@export var max_distance = 1000.0
@export var is_rotate = false
@export var hit_sound: AudiioConfig
@export var rotate_speed = 10.0

@export_group("Damage")
@export var damage = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.RANGED]
@export var tags: Array[String] = ["projectile"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
@export var is_penetrate = false

@onready var sprite2d: Sprite2D = $Sprite2D

var source: Entity
var current_dir = Vector2.ZERO
var current_distance = 0.0


# 初始化投射物飞行方向和来源。
func activate(context: AbilityContext):
	source = context.caster
	if not EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.connect(_handle_game_pause)
	if not EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.connect(_handle_scene_changed)
	if context.targets.size() > 0:
		var target_pos = context.get_target_positon(0)
		current_dir = (target_pos - global_position).normalized()
		look_at(target_pos)


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.disconnect(_handle_game_pause)
	if EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.disconnect(_handle_scene_changed)


# 推进投射物移动，并在超过最远距离时销毁。
func _process(delta: float) -> void:
	if source != null and not is_instance_valid(source):
		queue_free()
		return

	var movement = current_dir * delta * speed
	current_distance += movement.length()
	global_position += movement

	if is_rotate:
		global_rotation += delta * rotate_speed

	if current_distance >= max_distance:
		queue_free()


# 跟随全局暂停状态处理贴图动画暂停。
func _handle_game_pause(pause: bool):
	if sprite2d.texture is AnimatedTexture:
		(sprite2d.texture as AnimatedTexture).pause = pause


# 切回 home 场景时清理残留投射物。
func _handle_scene_changed(scene: String):
	if scene == "home":
		queue_free()


# 命中目标时创建 DamageData 并交给目标的统一受伤逻辑处理。
# 真正的暴击、成长、减伤都不在这里写死，而是走后面的统一链路。
func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent == null or not parent.is_in_group(target_group):
		return

	if parent is Entity:
		var valid_source := _get_valid_source()
		if source != null and valid_source == null:
			queue_free()
			return

		var damage_data := DamageData.create(
			damage,
			damage_types,
			tags,
			valid_source,
			parent,
			can_crit,
			scaling_rule
		)
		parent.apply_damage(damage_data)

		if hit_sound != null:
			AudioController.play(hit_sound, global_position)

		if is_penetrate:
			return

		queue_free()


func _get_valid_source() -> Entity:
	# 投射物可能比施法者活得更久；如果施法者已释放，不能再把这个旧引用传给 DamageData。
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source
