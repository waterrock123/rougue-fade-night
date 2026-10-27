class_name BattleTargetIndicatorController
extends Control

## 战场目标追踪 UI：普通敌人按方向合并，悬赏精英怪始终单独显示。

@export_range(0.02, 1.0, 0.02) var refresh_interval: float = 0.1
@export_range(20.0, 240.0, 5.0) var edge_margin: float = 76.0
@export_range(4, 16, 1) var ordinary_direction_sectors: int = 8

@onready var remaining_label: Label = %RemainingLabel

var enemy_spawner: EnemySpawner
var battle_camera: Camera2D
var refresh_timer: float = 0.0
var ordinary_indicators: Array[BattleTargetIndicator] = []
var bounty_indicators: Array[BattleTargetIndicator] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func bind(new_enemy_spawner: EnemySpawner, new_camera: Camera2D) -> void:
	enemy_spawner = new_enemy_spawner
	battle_camera = new_camera
	set_process(enemy_spawner != null and battle_camera != null)
	_refresh_indicators()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = refresh_interval
	_refresh_indicators()


func _refresh_indicators() -> void:
	if enemy_spawner == null or battle_camera == null or not is_instance_valid(enemy_spawner) or not is_instance_valid(battle_camera):
		_deactivate_all_indicators()
		remaining_label.hide()
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= edge_margin * 2.0 or viewport_size.y <= edge_margin * 2.0:
		_deactivate_all_indicators()
		return
	var center: Vector2 = viewport_size * 0.5
	var safe_rect := Rect2(
		Vector2(edge_margin, edge_margin),
		viewport_size - Vector2.ONE * edge_margin * 2.0
	)
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()

	_refresh_remaining_label()
	_refresh_ordinary_indicators(center, safe_rect, canvas_transform)
	_refresh_bounty_indicators(center, safe_rect, canvas_transform)


func _refresh_remaining_label() -> void:
	var remaining: int = enemy_spawner.get_remaining_victory_enemy_count()
	remaining_label.visible = remaining > 0
	remaining_label.text = "剩余敌人：%d" % remaining


func _refresh_ordinary_indicators(center: Vector2, safe_rect: Rect2, canvas_transform: Transform2D) -> void:
	var sector_count: int = maxi(ordinary_direction_sectors, 1)
	var direction_sums: Array[Vector2] = []
	var counts: Array[int] = []
	direction_sums.resize(sector_count)
	counts.resize(sector_count)
	for sector_index: int in range(sector_count):
		direction_sums[sector_index] = Vector2.ZERO
		counts[sector_index] = 0

	for enemy: Enemy in enemy_spawner.get_active_victory_enemies():
		var screen_position: Vector2 = canvas_transform * enemy.global_position
		if safe_rect.has_point(screen_position):
			continue
		var direction: Vector2 = (screen_position - center).normalized()
		if direction.is_zero_approx():
			continue
		var sector_index: int = _direction_to_sector(direction, sector_count)
		direction_sums[sector_index] += direction
		counts[sector_index] += 1

	for sector_index: int in range(sector_count):
		if counts[sector_index] <= 0:
			if sector_index < ordinary_indicators.size():
				ordinary_indicators[sector_index].deactivate()
			continue
		var direction: Vector2 = direction_sums[sector_index].normalized()
		# 每个扇区固定复用同一个箭头，避免分组变化时箭头互相换位。
		var indicator: BattleTargetIndicator = _get_indicator(ordinary_indicators, sector_index)
		indicator.configure(_get_edge_position(center, safe_rect, direction), direction, counts[sector_index], false)
	for unused_index: int in range(sector_count, ordinary_indicators.size()):
		ordinary_indicators[unused_index].deactivate()


func _refresh_bounty_indicators(center: Vector2, safe_rect: Rect2, canvas_transform: Transform2D) -> void:
	var indicator_index: int = 0
	for enemy: Enemy in enemy_spawner.get_active_bounty_enemies():
		var screen_position: Vector2 = canvas_transform * enemy.global_position
		if safe_rect.has_point(screen_position):
			continue
		var direction: Vector2 = (screen_position - center).normalized()
		if direction.is_zero_approx():
			continue
		var indicator: BattleTargetIndicator = _get_indicator(bounty_indicators, indicator_index)
		indicator.configure(_get_edge_position(center, safe_rect, direction), direction, 1, true)
		indicator_index += 1
	for unused_index: int in range(indicator_index, bounty_indicators.size()):
		bounty_indicators[unused_index].deactivate()


func _direction_to_sector(direction: Vector2, sector_count: int) -> int:
	var sector_angle: float = TAU / float(sector_count)
	var normalized_angle: float = fposmod(direction.angle() + sector_angle * 0.5, TAU)
	return mini(floori(normalized_angle / sector_angle), sector_count - 1)


func _get_edge_position(center: Vector2, safe_rect: Rect2, direction: Vector2) -> Vector2:
	var horizontal_distance: float = INF
	var vertical_distance: float = INF
	if not is_zero_approx(direction.x):
		horizontal_distance = (safe_rect.end.x - center.x) / direction.x if direction.x > 0.0 else (safe_rect.position.x - center.x) / direction.x
	if not is_zero_approx(direction.y):
		vertical_distance = (safe_rect.end.y - center.y) / direction.y if direction.y > 0.0 else (safe_rect.position.y - center.y) / direction.y
	return center + direction * minf(absf(horizontal_distance), absf(vertical_distance))


func _get_indicator(pool: Array[BattleTargetIndicator], index: int) -> BattleTargetIndicator:
	while pool.size() <= index:
		var indicator := BattleTargetIndicator.new()
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(indicator)
		pool.append(indicator)
	return pool[index]


func _deactivate_all_indicators() -> void:
	for indicator: BattleTargetIndicator in ordinary_indicators:
		indicator.deactivate()
	for indicator: BattleTargetIndicator in bounty_indicators:
		indicator.deactivate()
