@tool
class_name BattleMapDraftSettings
extends Resource
## 地图工坊配置。只描述布局与素材来源，不读取局内随机流或玩家存档。

enum LayoutStyle { RING, CLEARINGS, ARENA }

@export var layout_style: LayoutStyle = LayoutStyle.RING
@export var seed_value: int = 654321
@export_range(48, 128, 1) var width: int = 72
@export_range(36, 96, 1) var height: int = 48
@export_range(5, 13, 2) var passage_width: int = 7
@export_range(3, 7, 1) var clearing_count: int = 5
@export_range(0, 16, 1) var obstacle_count: int = 5
@export_range(0, 3, 1) var ground_padding: int = 1
## 从此场景只读取 TileSet 和物体生成配置，绝不实例化整张源地图。
@export_file("*.tscn") var palette_scene: String = "res://scenes/battlemap/templates/grass_open_01.tscn"
@export var grass_terrain: String = "grass"
@export var road_terrain: String = "road"
@export var hill_terrain: String = "hill"


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if width < 48 or width > 128 or height < 36 or height > 96:
		errors.append("地图尺寸必须在48～128列、36～96行之间。")
	if passage_width < 5 or passage_width > 13 or passage_width % 2 == 0:
		errors.append("通道宽度必须是5～13之间的奇数。")
	if clearing_count < 3 or clearing_count > 7 or obstacle_count < 0 or obstacle_count > 16:
		errors.append("空地数量应为3～7，障碍簇数量应为0～16。")
	if layout_style < LayoutStyle.RING or layout_style > LayoutStyle.ARENA:
		errors.append("未知的布局类型。")
	if ground_padding < 0 or ground_padding > 3:
		errors.append("草地外扩范围必须是0～3格。")
	return errors
