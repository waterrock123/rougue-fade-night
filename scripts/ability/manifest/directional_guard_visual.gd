## 只绘制防御朝向，不参与格挡判定；亮金色表示精准窗口，淡白色表示普通防御。
class_name DirectionalGuardVisual
extends Node2D

var angle_degrees: float = 180.0
var perfect: bool = true


func _draw() -> void:
	var half: float = deg_to_rad(angle_degrees * 0.5)
	var color: Color = Color(1.0, 0.85, 0.4, 0.9) if perfect else Color(0.8, 0.9, 1.0, 0.6)
	draw_arc(Vector2.ZERO, 28.0, -half, half, 24, color, 1.5, false)
