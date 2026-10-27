class_name HubCamera
extends Camera2D

## 大厅镜头只负责跟随大厅角色与缩放，不与战斗镜头、屏幕震动逻辑耦合。
## Godot 的 Camera2D zoom 数值越大，画面越靠近角色。

@export_group("缩放")
@export_range(0.5, 10.0, 0.1) var default_zoom_scale: float = 4.0
@export_range(0.5, 10.0, 0.1) var min_zoom_scale: float = 2.5
@export_range(0.5, 10.0, 0.1) var max_zoom_scale: float = 6.0
@export_range(0.1, 2.0, 0.1) var zoom_step: float = 0.5
@export_range(1.0, 30.0, 0.5) var zoom_smoothing_speed: float = 12.0

var target_zoom_scale: float


func _ready() -> void:
	target_zoom_scale = clampf(default_zoom_scale, min_zoom_scale, max_zoom_scale)
	zoom = Vector2.ONE * target_zoom_scale
	enabled = true


func _process(delta: float) -> void:
	var target_zoom := Vector2.ONE * target_zoom_scale
	zoom = zoom.lerp(target_zoom, clampf(delta * zoom_smoothing_speed, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_change_zoom(zoom_step)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_change_zoom(-zoom_step)


func _change_zoom(amount: float) -> void:
	target_zoom_scale = clampf(target_zoom_scale + amount, min_zoom_scale, max_zoom_scale)
