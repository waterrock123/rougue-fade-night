@tool
extends Node2D
## 仅供工坊预览的出生点标记，不保存到地图，不是正式游戏美术。

var player_position: Vector2
var enemy_positions: PackedVector2Array = []


func _draw() -> void:
	_draw_marker(player_position, Color(0.3, 1.0, 0.65), "P")
	for point: Vector2 in enemy_positions:
		_draw_marker(point, Color(1.0, 0.35, 0.25), "E")


func _draw_marker(point: Vector2, color: Color, text: String) -> void:
	draw_circle(point, 5.0, Color(0.04, 0.06, 0.09, 0.9))
	draw_arc(point, 6.0, 0.0, TAU, 24, color, 1.5, true)
	draw_string(ThemeDB.fallback_font, point + Vector2(8, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
