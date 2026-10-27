class_name TutorialWorldMarker
extends Node2D

## 教学用范围标注，不是地图实体或替代美术；只标出当前目标位置。
@export var radius: float = 22.0
@export var color: Color = Color(0.45, 0.9, 1.0, 0.9)
var clock: float = 0.0
@onready var caption: Label = $Caption


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.75 + 0.25 * sin(clock * 3.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.1 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, pulse), 1.5, false)


func set_caption(text: String) -> void:
	if caption != null:
		caption.text = text
