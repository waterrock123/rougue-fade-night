## 怪物出招预警组件。
## 只负责在技能真正造成伤害前画出红色警示区域，不负责查找目标或造成伤害。
## 适合 Boss/精英怪的延迟斩击、冲击波、落雷、范围爆炸等需要给玩家反应时间的技能。
class_name AbilityEnemyTelegraph
extends AbilityComponent

enum TelegraphShape {
	SECTOR,
	CIRCLE,
	LINE_RECT,
}

enum DirectionMode {
	FACING,
	PLAYER,
	FIRST_TARGET,
	LOCKED_CONTEXT,
}

@export_category("预警形状")
@export var shape: TelegraphShape = TelegraphShape.SECTOR
@export var direction_mode: DirectionMode = DirectionMode.FACING
## 扇形/直线矩形中表示长度；圆形中表示半径。
@export var range: float = 120.0
@export_range(1.0, 360.0) var angle_degrees: float = 90.0
@export var width: float = 80.0
@export var circle_segments: int = 48

@export_category("预警位置")
@export var origin_offset: Vector2 = Vector2.ZERO
## 沿预警方向向前偏移，适合把第二段 AOE 放到第一段攻击末端。
@export var forward_offset: float = 0.0
## 沿预警方向的右侧偏移，通常用于微调表现位置。
@export var side_offset: float = 0.0

@export_category("显示效果")
@export var warning_duration: float = 0.4
@export var fill_color: Color = Color(1.0, 0.05, 0.02, 0.28)
@export var border_color: Color = Color(1.0, 0.15, 0.08, 0.9)
@export var border_width: float = 3.0
@export var fade_in_time: float = 0.06
@export var fade_out_time: float = 0.1
@export var pulse: bool = true
@export var pulse_scale: float = 1.05
## 开启后会把预警方向写入 AbilityContext，后续 AbilityGetTargets/SpawnManifest 可读取同一方向。
@export var write_direction_to_context: bool = true

var polygon: Polygon2D
var border: Line2D
var active_tween: Tween


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null or not context.is_caster_action_valid():
		return

	_spawn_warning(context)
	if warning_duration > 0.0:
		await get_tree().create_timer(warning_duration, false).timeout
	if context == null or not context.is_caster_action_valid():
		_clear_warning()
		return
	_clear_warning()


# 创建并放置预警图形。图形挂到当前场景根节点下，避免跟着怪物动画或缩放乱动。
func _spawn_warning(context: AbilityContext) -> void:
	_clear_warning()
	var points := _build_shape_points()
	var direction := _get_warning_direction(context)
	var warning_position := _get_warning_position(context, direction)
	if write_direction_to_context:
		context.locked_direction = direction

	polygon = Polygon2D.new()
	polygon.polygon = points
	polygon.color = Color(fill_color.r, fill_color.g, fill_color.b, 0.0)
	polygon.global_position = warning_position
	polygon.global_rotation = direction.angle()
	polygon.z_index = 900

	border = Line2D.new()
	border.points = points
	border.closed = true
	border.default_color = Color(border_color.r, border_color.g, border_color.b, 0.0)
	border.width = border_width
	border.global_position = warning_position
	border.global_rotation = direction.angle()
	border.z_index = 901

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(polygon)
	root.add_child(border)

	_play_warning_tween()


# 根据配置生成局部坐标下的形状点，随后整体旋转到怪物面向方向。
func _build_shape_points() -> PackedVector2Array:
	match shape:
		TelegraphShape.SECTOR:
			return _build_sector_points()
		TelegraphShape.CIRCLE:
			return _build_circle_points()
		TelegraphShape.LINE_RECT:
			return _build_line_rect_points()

	return PackedVector2Array()


# 扇形从原点向前展开，适合斩击、喷吐、剑气等前方范围攻击。
func _build_sector_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var safe_segments: int = max(int(ceil(angle_degrees / 8.0)), 8)
	var half_angle := deg_to_rad(angle_degrees * 0.5)

	for index in range(safe_segments + 1):
		var t := float(index) / float(safe_segments)
		var angle = lerp(-half_angle, half_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * range)

	points.append(Vector2.ZERO)
	return points


# 圆形使用 range 作为半径。想调小红圈时改 range，不是 width。
func _build_circle_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(circle_segments, 12)

	for index in range(safe_segments):
		var angle := TAU * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle), sin(angle)) * range)

	return points


# 直线矩形适合冲锋、激光、长条剑气。
func _build_line_rect_points() -> PackedVector2Array:
	var half_width := width * 0.5
	return PackedVector2Array([
		Vector2(0.0, -half_width),
		Vector2(range, -half_width),
		Vector2(range, half_width),
		Vector2(0.0, half_width),
	])


func _get_warning_direction(context: AbilityContext) -> Vector2:
	match direction_mode:
		DirectionMode.LOCKED_CONTEXT:
			if context.locked_direction != Vector2.ZERO:
				return context.locked_direction.normalized()
		DirectionMode.PLAYER:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player != null:
				return context.caster.global_position.direction_to(player.global_position)
		DirectionMode.FIRST_TARGET:
			if not context.targets.is_empty():
				var target = context.targets[0]
				if target is Node2D:
					return context.caster.global_position.direction_to(target.global_position)
				if target is Vector2:
					return context.caster.global_position.direction_to(target)

	var facing := context.caster.get_facing_direction()
	return facing if facing != Vector2.ZERO else Vector2.RIGHT


func _get_warning_position(context: AbilityContext, direction: Vector2) -> Vector2:
	var offset := origin_offset
	if direction != Vector2.ZERO:
		var normalized_direction := direction.normalized()
		var right := Vector2(-normalized_direction.y, normalized_direction.x)
		offset += normalized_direction * forward_offset + right * side_offset
	return context.caster.global_position + offset


# 淡入和轻微脉冲能让预警更醒目，但保持低成本，方便大量怪物复用。
func _play_warning_tween() -> void:
	if polygon == null or border == null:
		return

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(polygon, "color:a", fill_color.a, fade_in_time)
	active_tween.tween_property(border, "default_color:a", border_color.a, fade_in_time)

	if pulse:
		polygon.scale = Vector2.ONE
		border.scale = Vector2.ONE
		active_tween.tween_property(polygon, "scale", Vector2.ONE * pulse_scale, warning_duration).set_trans(Tween.TRANS_SINE)
		active_tween.tween_property(border, "scale", Vector2.ONE * pulse_scale, warning_duration).set_trans(Tween.TRANS_SINE)


# 清理预警。技能被打断、怪物死亡或场景切换时也能安全释放。
func _clear_warning() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null

	if polygon == null and border == null:
		return

	if fade_out_time > 0.0 and is_inside_tree():
		var fade_tween := create_tween()
		fade_tween.set_parallel(true)
		if polygon != null and is_instance_valid(polygon):
			fade_tween.tween_property(polygon, "color:a", 0.0, fade_out_time)
		if border != null and is_instance_valid(border):
			fade_tween.tween_property(border, "default_color:a", 0.0, fade_out_time)
		fade_tween.chain().tween_callback(_free_warning_nodes)
	else:
		_free_warning_nodes()


func _free_warning_nodes() -> void:
	if polygon != null and is_instance_valid(polygon):
		polygon.queue_free()
	if border != null and is_instance_valid(border):
		border.queue_free()
	polygon = null
	border = null


func _exit_tree() -> void:
	_free_warning_nodes()
