class_name MapObjectVariantEntry
extends Resource

## 变体池中的一个候选地图物体。
## 例如 animal_chicken / animal_cow 都可以作为同一个 animal 池的变体。
@export var object_id: StringName
@export var weight: float = 1.0


func is_valid_entry() -> bool:
	return object_id != &"" and weight > 0.0

