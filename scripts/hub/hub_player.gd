class_name HubPlayer
extends CharacterBody2D

## 大厅专用角色控制器。
## 它只负责移动、镜头与角色外观展示，不挂载战斗属性、技能或装备逻辑，
## 避免局外大厅与一局 Run 的运行时数据互相污染。

@export_group("移动")
@export var move_speed: float = 150.0

## 大厅模态面板打开时停止读取移动输入，保留待机动画更新。
var controls_enabled: bool = true

@export_group("角色外观")
@export var character: Character

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	add_to_group("hub_player")
	_apply_character_visual()


func _physics_process(_delta: float) -> void:
	var move_direction := Input.get_vector(&"leftmove", &"rightmove", &"upmove", &"downmove")
	if not controls_enabled:
		move_direction = Vector2.ZERO
	velocity = move_direction * move_speed
	move_and_slide()
	_update_animation(move_direction)


## 后续角色选择或联网房间确认角色后，可调用此方法刷新大厅中的外观。
func set_character(new_character: Character) -> void:
	character = new_character
	_apply_character_visual()


func _apply_character_visual() -> void:
	if animated_sprite == null:
		return
	# 切换到尚未配置动画的角色时清空旧外观，避免保留上一个角色的图像。
	animated_sprite.stop()
	animated_sprite.sprite_frames = null
	animated_sprite.visible = false
	if character == null or character.visual_data == null or character.visual_data.sprite_frames == null:
		push_warning("大厅当前角色尚未配置完整的 CharacterVisualData。")
		return

	var visual_data := character.visual_data
	if visual_data.sprite_frames != null:
		animated_sprite.sprite_frames = visual_data.sprite_frames
	animated_sprite.visible = true
	animated_sprite.position = visual_data.visual_offset
	animated_sprite.scale = visual_data.visual_scale
	animated_sprite.flip_h = visual_data.default_facing_left

	if visual_data.has_animation(visual_data.default_animation):
		animated_sprite.play(visual_data.default_animation)
	elif visual_data.has_animation(&"idle"):
		animated_sprite.play(&"idle")


func _update_animation(move_direction: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	if not is_zero_approx(move_direction.x):
		var default_facing_left := character.visual_data.default_facing_left if character != null and character.visual_data != null else false
		animated_sprite.flip_h = move_direction.x < 0.0 if not default_facing_left else move_direction.x > 0.0

	var moving := move_direction.length_squared() > 0.0
	if moving:
		if animated_sprite.sprite_frames.has_animation(&"run"):
			_play_animation_if_needed(&"run")
		elif animated_sprite.sprite_frames.has_animation(&"walk"):
			_play_animation_if_needed(&"walk")
	elif animated_sprite.sprite_frames.has_animation(&"idle"):
		_play_animation_if_needed(&"idle")


## 仅在状态切换时播放动画，避免移动期间反复写入同一个动画状态。
func _play_animation_if_needed(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
