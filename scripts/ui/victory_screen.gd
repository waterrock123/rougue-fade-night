class_name VictoryScreen
extends Control

const HOME_SCENE := preload("res://scenes/home_scene.tscn")

@onready var background: ColorRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel


func _ready() -> void:
	get_tree().paused = false
	_play_victory_sequence()


# 通关界面只负责展示和离场；本局数据删除由 Run 先执行，这里再兜底删除一次也安全。
func _play_victory_sequence() -> void:
	if background != null:
		background.color.a = 0.0
	if title_label != null:
		title_label.modulate.a = 0.0
	if subtitle_label != null:
		subtitle_label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	if background != null:
		tween.tween_property(background, "color:a", 0.92, 1.0)
	if title_label != null:
		tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_delay(0.25)
	if subtitle_label != null:
		tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.8).set_delay(0.75)

	tween.chain().tween_interval(2.0)
	if title_label != null:
		tween.tween_property(title_label, "modulate:a", 0.0, 0.8)
	if subtitle_label != null:
		tween.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 0.8)
	if background != null:
		tween.parallel().tween_property(background, "color:a", 1.0, 0.8)
	tween.chain().tween_callback(_return_to_home)


func _return_to_home() -> void:
	Run.pending_startup = null
	SaveManager.delete_save()
	get_tree().change_scene_to_packed(HOME_SCENE)
