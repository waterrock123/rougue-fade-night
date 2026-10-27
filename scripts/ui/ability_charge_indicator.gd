## 仅绘制局部原点上的蓄力圆环；大小和挂载位置交给技能组件配置，不处理输入与伤害。
class_name AbilityChargeIndicator
extends Node2D

var ratio: float = 0.0
@export var radius: float = 20.0
@export var line_width: float = 2.0


func _draw() -> void:
	var ring_radius: float = maxf(radius, 1.0)
	var thickness: float = maxf(line_width, 0.5)
	draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5, PI * 1.5, 48, Color(0.08, 0.1, 0.18, 0.8), thickness + 1.0, true)
	if ratio > 0.0:
		var color: Color = Color(1.0, 0.88, 0.45) if ratio >= 1.0 else Color(0.65, 0.7, 1.0)
		draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 48, color, thickness, true)
