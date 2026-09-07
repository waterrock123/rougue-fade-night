class_name MapObjectSpawnRule
extends Resource

## 单种地图物件的随机生成规则。
## object_id 对应 MapObjectDatabase 里的配置，例如 apple_tree / rock。

@export var enabled: bool = true
@export var object_id: StringName
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var min_count: int = 0
@export var max_count: int = 0
## 当 Profile 开启额外权重生成时使用；普通按数量生成时不会受它影响。
@export var weight: float = 1.0
## 先由规则决定“动物”这类大类，再从变体池决定具体场景。
@export var variant_pool: MapObjectVariantPool

@export_group("位置规则")
@export var require_walkable: bool = true
@export var avoid_player_spawn: bool = true
@export var min_distance_from_player_spawn: float = 96.0
@export var avoid_enemy_spawns: bool = true
@export var min_distance_from_enemy_spawns: float = 56.0
@export var min_distance_from_other_objects: float = 32.0
@export var max_attempts_per_object: int = 80
## 只影响此规则生成出的物件，适合让某类物件整体微调脚底点。
@export var spawn_offset: Vector2 = Vector2.ZERO


func is_valid_rule() -> bool:
	return enabled and object_id != &"" and max_count >= 0


func can_be_weighted_pick() -> bool:
	return is_valid_rule() and weight > 0.0


func roll_count() -> int:
	if not is_valid_rule():
		return 0
	if randf() > clamp(chance, 0.0, 1.0):
		return 0

	var safe_min_count: int = max(min_count, 0)
	var safe_max_count: int = max(max_count, safe_min_count)
	return randi_range(safe_min_count, safe_max_count)
