## 通用投射物拖尾：记录投射物的世界坐标，再转换回 Line2D 的局部坐标绘制。
## 这样父节点移动时，拖尾仍然会保留在投射物经过的世界路径上。
class_name ProjectileTrail2D
extends Line2D

@export var max_points: int = 10
@export var point_distance: float = 3.0
@export var trail_color: Color = Color(1.0, 1.0, 1.0, 0.7)
@export var trail_width: float = 3.0

var world_points: Array[Vector2] = []


func _ready() -> void:
	default_color = trail_color
	width = trail_width


func _process(_delta: float) -> void:
	var projectile: Node2D = get_parent() as Node2D
	if projectile == null:
		return

	var current_position: Vector2 = projectile.global_position
	if world_points.is_empty() or world_points.back().distance_to(current_position) >= point_distance:
		world_points.append(current_position)
	while world_points.size() > maxi(max_points, 2):
		world_points.pop_front()

	var local_points: PackedVector2Array = PackedVector2Array()
	for world_point: Vector2 in world_points:
		local_points.append(to_local(world_point))
	points = local_points
