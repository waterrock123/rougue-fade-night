class_name MapDropEntry
extends Resource

## 地图物件掉落配置。
## 一个 MapObject 可以配置多个 Entry：例如受击小概率掉苹果，摧毁时必定掉 1-2 个苹果。

@export var pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
@export var spawn_radius: float = 14.0


func roll_count() -> int:
	if pickup_scene == null:
		return 0
	if randf() > clamp(chance, 0.0, 1.0):
		return 0

	var safe_min_count: int = max(min_count, 0)
	var safe_max_count: int = max(max_count, safe_min_count)
	return randi_range(safe_min_count, safe_max_count)
