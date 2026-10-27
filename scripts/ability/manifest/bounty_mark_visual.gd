## 轻量赏金瞄准标记，只负责视觉，不产生碰撞或伤害；无需额外美术API。
class_name BountyMarkVisual
extends Node2D


func _ready() -> void:
	z_index = 110


func _draw() -> void:
	var color: Color = Color(1.0, 0.82, 0.3, 0.95)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 24, color, 1.0, true)
	draw_line(Vector2(-11, 0), Vector2(-4, 0), color, 1.0)
	draw_line(Vector2(4, 0), Vector2(11, 0), color, 1.0)
	draw_line(Vector2(0, -11), Vector2(0, -4), color, 1.0)
	draw_line(Vector2(0, 4), Vector2(0, 11), color, 1.0)
