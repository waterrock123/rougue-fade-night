class_name MapObjectEntry
extends Resource

## 地图物件数据库中的单条配置。
## object_id 必须和 ObjectSpawnLayer 瓦片 custom data 里的 object_id 完全一致。

@export var object_id: StringName
@export var scene: PackedScene
@export var enabled: bool = true
## 单个物件自己的生成偏移；适合树、柱子这类视觉脚底不在瓦片中心的场景。
@export var spawn_offset: Vector2 = Vector2.ZERO


func is_valid_entry() -> bool:
	return enabled and object_id != &"" and scene != null
