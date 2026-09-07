## 动画帧命中盒 Manifest。
## 像一个短生命周期的“陷阱/范围投射物”：
## 动画播放到指定帧时，检查 Area2D 当前重叠的目标并造成伤害；动画结束后自动释放。
## 可复用于剑气、地面爆炸、陷阱、冲击波余波等依赖动画帧结算命中的效果。
class_name AnimatedHitboxManifest
extends AbilityManifest

@export_group("Animation")
@export var animation_name: StringName = &"default"
@export var free_when_finished: bool = true
@export var face_locked_direction: bool = true

@export_group("Hit Check")
@export var target_group: StringName = &"player"
@export var damage_frames: Array[int] = [3, 6]
@export var hit_once_per_frame: bool = true

@export_group("Damage")
@export var damage: float = 18.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["manifest", "skill", "hitbox", "animated_hitbox", "melee_effect"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
## 动画命中盒每次有效判定默认造成 10 点削韧；多段判定会分别结算。
@export var poise_damage: float = 10.0
@export var hit_sound: AudiioConfig

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: Area2D = $Area2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var triggered_frames: Dictionary = {}


func _ready() -> void:
	if animated_sprite != null and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _exit_tree() -> void:
	if animated_sprite != null and animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_animation_finished)


func activate(context: AbilityContext) -> void:
	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1
	triggered_frames.clear()

	if face_locked_direction and context.locked_direction != Vector2.ZERO:
		global_rotation = context.locked_direction.angle()

	if animated_sprite == null:
		return

	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
	animated_sprite.play(animation_name)


func _process(_delta: float) -> void:
	if source != null and not is_instance_valid(source):
		queue_free()
		return
	if source != null and source.is_dead:
		queue_free()
		return
	if animated_sprite == null:
		return

	_try_trigger_damage_frames(animated_sprite.frame)


# 动画帧可能因为帧率波动被跳过，所以这里使用“当前帧 >= 触发帧”来兜底。
func _try_trigger_damage_frames(current_frame: int) -> void:
	for frame_index in damage_frames:
		if triggered_frames.has(frame_index):
			continue
		if current_frame < frame_index:
			continue

		triggered_frames[frame_index] = true
		_apply_frame_damage()


# 每个触发帧独立做一次重叠检测，所以同一个目标可以在不同帧吃到多段伤害。
func _apply_frame_damage() -> void:
	if hit_area == null:
		return

	var valid_source := _get_valid_source()
	if source != null and valid_source == null:
		queue_free()
		return

	var damaged_targets: Array[Entity] = []
	for area in hit_area.get_overlapping_areas():
		var target := _get_entity_from_area(area)
		if target == null:
			continue
		if hit_once_per_frame and damaged_targets.has(target):
			continue

		_damage_target(target, valid_source)
		damaged_targets.append(target)

	if not damaged_targets.is_empty() and hit_sound != null:
		AudioController.play(hit_sound, global_position)


func _damage_target(target: Entity, valid_source: Entity) -> void:
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		valid_source,
		target,
		can_crit,
		scaling_rule,
		source_ability_id,
		source_ability_slot_index,
		poise_damage
	)
	target.apply_damage(damage_data)


func _get_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent := area.get_parent()
	if not (parent is Entity):
		return null

	var entity := parent as Entity
	if not entity.matches_target_group(target_group):
		return null
	if source != null and is_instance_valid(source) and entity == source:
		return null
	if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
		return null

	return entity


func _get_valid_source() -> Entity:
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source


func _on_animation_finished() -> void:
	if free_when_finished:
		queue_free()
