class_name MapObjectEntry
extends Resource

## 地图物件数据库中的单条配置。
## object_id 必须和 ObjectSpawnLayer 瓦片 custom data 里的 object_id 完全一致。
const FEATURE_KIND_SPECIAL_OBJECT: StringName = &"special_object"
const FEATURE_KIND_SPECIAL_TERRAIN: StringName = &"special_terrain"

@export var object_id: StringName
@export var scene: PackedScene
@export var enabled: bool = true
## 地图生成影响的大类。目前先分为“地图特殊物体”和“地图特殊地形”。
## 物体是可实例化、可交互的场景；地形通常由 TileMap 或地形规则层表达。
@export_enum("special_object", "special_terrain") var feature_kind: String = String(FEATURE_KIND_SPECIAL_OBJECT)
## 子分类标签，例如 beneficial_plant / animal / ammo_box。
## 标签影响地图时优先匹配这里，而不是写死某一个 object_id。
@export var feature_tags: Array[StringName] = []
## 单个物件自己的生成偏移；适合树、柱子这类视觉脚底不在瓦片中心的场景。
@export var spawn_offset: Vector2 = Vector2.ZERO


func is_valid_entry() -> bool:
	# scene 允许为空，用于登记“动物”这类只负责归类和匹配权重的抽象条目。
	return enabled and object_id != &""


func get_feature_kind() -> StringName:
	return StringName(feature_kind)


func is_special_object() -> bool:
	return get_feature_kind() == FEATURE_KIND_SPECIAL_OBJECT


func is_special_terrain() -> bool:
	return get_feature_kind() == FEATURE_KIND_SPECIAL_TERRAIN


func has_feature_tag(feature_tag: StringName) -> bool:
	return feature_tags.has(feature_tag)
