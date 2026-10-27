## 等候室只展示外观和插值位置，不读取输入、不加入player组，也不挂载战斗/背包逻辑。
class_name CoopLobbyAvatar
extends HubPlayer

var peer_id: int = 0
var target_position: Vector2
var has_snapshot: bool = false
var moving: bool = false
var facing: int = 1
var selected_id: String = ""
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	if character != null:
		_apply_character_visual()


func configure(entry: Dictionary, is_local: bool) -> void:
	peer_id = int(entry["peer_id"])
	var id: String = str(entry["character_id"])
	if selected_id != id:
		selected_id = id
		set_character(CoopLobbyRules.get_character(id) as Character)
	name_label.text = str(entry["name"]) + (" · 你" if is_local else "")
	name_label.modulate = Color(1, 0.86, 0.5) if is_local else Color(0.78, 0.9, 1)
	camera.enabled = is_local
	if is_local:
		camera.make_current()
	apply_snapshot(entry)


func apply_snapshot(entry: Dictionary) -> void:
	target_position = entry["position"]
	facing = int(entry["facing"])
	var motion: Vector2 = entry["movement"]
	moving = motion.length_squared() > 0.0001
	if not has_snapshot:
		position = target_position
		has_snapshot = true


func _physics_process(_delta: float) -> void:
	# 房主已经在房间模型中模拟移动；不能再执行HubPlayer的本机输入与move_and_slide。
	pass


func _process(delta: float) -> void:
	if not has_snapshot:
		return
	position = position.lerp(target_position, 1.0 - exp(-18.0 * maxf(delta, 0.0)))
	_update_remote_animation()


func _update_remote_animation() -> void:
	if character == null or character.visual_data == null or animated_sprite.sprite_frames == null:
		return
	var default_left: bool = character.visual_data.default_facing_left
	animated_sprite.flip_h = facing < 0 if not default_left else facing > 0
	var animation: StringName = &"idle"
	if moving:
		animation = &"run" if animated_sprite.sprite_frames.has_animation(&"run") else &"walk"
	if animated_sprite.sprite_frames.has_animation(animation):
		_play_animation_if_needed(animation)
