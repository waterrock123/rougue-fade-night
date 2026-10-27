@tool
extends SubViewportContainer
## 原生瓦片预览：不运行游戏。鼠标滚轮缩放、中键拖动，仅在变化时重绘。

const OVERLAY: Script = preload("res://addons/battle_map_workshop/spawn_overlay.gd")

var viewport: SubViewport
var camera: Camera2D
var overlay: Node2D
var scene_root: Node2D
var map_rect: Rect2
var zoom_factor: float = 1.0
var spawns_visible: bool = true


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(400, 380)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	viewport.add_child(camera)
	resized.connect(_fit_map)
	gui_input.connect(_on_preview_input)


func show_map(root: Node2D, layout: Dictionary) -> void:
	clear_map()
	scene_root = root
	viewport.add_child(scene_root)
	var ground: TileMapLayer = root.get_node("GroundLayer") as TileMapLayer
	var cell_size: Vector2 = Vector2(ground.tile_set.tile_size)
	var bounds: Rect2i = layout["bounds"]
	map_rect = Rect2(Vector2(bounds.position) * cell_size, Vector2(bounds.size) * cell_size)
	overlay = OVERLAY.new()
	overlay.set("player_position", root.get_node("SpawnPoints/PlayerSpawn").position)
	var positions: PackedVector2Array = []
	for marker: Node2D in root.get_node("SpawnPoints").get_children():
		if marker.name.begins_with("EnemySpawn"):
			positions.append(marker.position)
	overlay.set("enemy_positions", positions)
	overlay.z_index = 200
	overlay.visible = spawns_visible
	viewport.add_child(overlay)
	_fit_map()


func clear_map() -> void:
	for node: Node in [overlay, scene_root]:
		if is_instance_valid(node):
			viewport.remove_child(node)
			node.queue_free()
	overlay = null
	scene_root = null
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _fit_map() -> void:
	if map_rect.size.x <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	zoom_factor = minf(size.x / map_rect.size.x, size.y / map_rect.size.y) * 0.92
	camera.position = map_rect.get_center()
	camera.zoom = Vector2.ONE * zoom_factor
	_request_redraw()


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = clampf(zoom_factor * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.15, 6.0)
			camera.zoom = Vector2.ONE * zoom_factor
			_request_redraw()
			accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		camera.position -= event.relative / zoom_factor
		_request_redraw()
		accept_event()


func set_spawns_visible(value: bool) -> void:
	spawns_visible = value
	if is_instance_valid(overlay):
		overlay.visible = value
		_request_redraw()


func _request_redraw() -> void:
	# 两帧内完成TileMap批处理；静止后不持续渲染整个预览。
	if camera.is_inside_tree():
		camera.force_update_scroll()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_redraw_next_frame.call_deferred()


func _redraw_next_frame() -> void:
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
