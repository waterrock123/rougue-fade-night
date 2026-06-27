## 预览期视觉 Manifest 的生命周期脚本。
## 进入预览时播放出现动画；预览结束时播放 disappear 动画，动画结束后自动释放自身。
class_name PreviewLifecycleManifest
extends Node2D

signal appear_finished

@export var appear_animation: StringName = &"equip_gun"
@export var disappear_animation: StringName = &"disappear"
@export var animation_player_path: NodePath = ^"AnimationPlayer"

@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer

var has_finished_appear := false
var is_disappearing := false


func _ready() -> void:
	if animation_player == null:
		return
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func play_appear() -> void:
	is_disappearing = false
	has_finished_appear = false
	if animation_player == null:
		_mark_appear_finished()
		return
	if animation_player.has_animation(appear_animation):
		animation_player.play(appear_animation)
	else:
		_mark_appear_finished()


func request_disappear() -> void:
	if is_disappearing:
		return

	is_disappearing = true
	if animation_player == null or not animation_player.has_animation(disappear_animation):
		queue_free()
		return

	animation_player.play(disappear_animation)


func _on_animation_finished(animation_name: StringName) -> void:
	if not is_disappearing and animation_name == appear_animation:
		_mark_appear_finished()
		return

	if is_disappearing and animation_name == disappear_animation:
		queue_free()


func has_finished_appear_animation() -> bool:
	return has_finished_appear


func _mark_appear_finished() -> void:
	if has_finished_appear:
		return

	has_finished_appear = true
	appear_finished.emit()
