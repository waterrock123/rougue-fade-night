class_name DialogueUI
extends Control

signal dialogue_finished()

@export var fade_time: float = 0.18
@export var default_duration: float = 1.8

@onready var name_label: RichTextLabel = $VBoxContainer/PanelContainer/RichTextLabel
@onready var content_label: RichTextLabel = $VBoxContainer/HBoxContainer/PanelContainer2/RichTextLabel

var active_tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	hide()


# 显示一句对白，淡入后停留一小段时间，再淡出。
func show_dialogue(speaker_name: String, text: String, duration: float = -1.0) -> void:
	if text.strip_edges().is_empty():
		return

	if active_tween != null and active_tween.is_running():
		active_tween.kill()

	if name_label != null:
		name_label.clear()
		name_label.append_text(speaker_name)
	if content_label != null:
		content_label.clear()
		content_label.append_text(text)

	show()
	modulate.a = 0.0
	var stay_time := default_duration if duration < 0.0 else duration
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 1.0, fade_time)
	active_tween.tween_interval(stay_time)
	active_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	active_tween.tween_callback(_finish_dialogue)


# 需要等待对白播放完毕的流程（例如离开修整期）调用这个方法。
func show_dialogue_and_wait(speaker_name: String, text: String, duration: float = -1.0) -> void:
	show_dialogue(speaker_name, text, duration)
	if text.strip_edges().is_empty():
		return
	await dialogue_finished


func _finish_dialogue() -> void:
	hide()
	dialogue_finished.emit()
