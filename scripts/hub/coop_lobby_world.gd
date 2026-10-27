## 独立SubViewport中的展示世界，只渲染房间快照，不运行NPC、剧情、装备和地图生成。
class_name CoopLobbyWorld
extends Node2D

const AVATAR: PackedScene = preload("res://scenes/hub/coop_lobby_avatar.tscn")
var avatars: Dictionary = {}
var session: CoopLobbySession
var floor_layer: TileMapLayer
@onready var overview_camera: Camera2D = $OverviewCamera


func bind_session(value: CoopLobbySession) -> void:
	session = value
	session.room_changed.connect(_on_roster)
	session.motion_changed.connect(_on_motion)
	_on_roster(session.state.roster_snapshot())
	queue_redraw()


func build_floor(tiles: TileSet) -> void:
	if tiles == null or tiles.get_source_count() == 0 or floor_layer != null:
		return
	var source_id: int = tiles.get_source_id(0)
	var source: TileSetAtlasSource = tiles.get_source(source_id) as TileSetAtlasSource
	if source == null or source.get_tiles_count() == 0:
		return
	# 复用大厅已配置的草地中心格；素材变动时回退到该图集中的有效格，不制造新美术。
	var coord: Vector2i = Vector2i(1, 1) if source.has_tile(Vector2i(1, 1)) else source.get_tile_id(0)
	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = tiles
	floor_layer.collision_enabled = false
	floor_layer.navigation_enabled = false
	floor_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_layer.z_index = -5
	add_child(floor_layer)
	for y: int in range(-24, 25):
		for x: int in range(-35, 36):
			floor_layer.set_cell(Vector2i(x, y), source_id, coord)


func _on_roster(_snapshot: Dictionary) -> void:
	if session == null:
		return
	for id: int in avatars.keys():
		if not session.state.players.has(id):
			var old: CoopLobbyAvatar = avatars[id] as CoopLobbyAvatar
			avatars.erase(id)
			remove_child(old)
			old.queue_free()
	for id: int in session.state.players.keys():
		if not avatars.has(id):
			var avatar: CoopLobbyAvatar = AVATAR.instantiate() as CoopLobbyAvatar
			avatar.name = "LobbyPlayer_%d" % id
			add_child(avatar)
			avatars[id] = avatar
		(avatars[id] as CoopLobbyAvatar).configure(session.state.players[id], id == session.local_peer_id())
	if avatars.is_empty():
		overview_camera.make_current()


func _on_motion(entries: Array) -> void:
	for entry: Dictionary in entries:
		var id: int = int(entry["peer_id"])
		if avatars.has(id):
			(avatars[id] as CoopLobbyAvatar).apply_snapshot(entry)


func _draw() -> void:
	# 边线只是可走范围提示，不是地图物体；本阶段的空房间由房主做矩形边界约束。
	draw_rect(CoopLobbyRules.BOUNDS, Color(1, 0.88, 0.55, 0.45), false, 1.0)


func _exit_tree() -> void:
	if not is_instance_valid(session):
		return
	if session.room_changed.is_connected(_on_roster):
		session.room_changed.disconnect(_on_roster)
	if session.motion_changed.is_connected(_on_motion):
		session.motion_changed.disconnect(_on_motion)
