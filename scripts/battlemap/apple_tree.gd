class_name AppleTree
extends MapObject

## 苹果树示例互动物。
## 它内置“受击概率掉苹果、摧毁必掉苹果”的测试逻辑；也仍然可以叠加 MapObject 的通用掉落表。

const DEFAULT_APPLE_PICKUP_SCENE = preload("res://scenes/battlemap/apple_pickup.tscn")

@export_group("苹果掉落")
@export var apple_pickup_scene: PackedScene = DEFAULT_APPLE_PICKUP_SCENE
@export_range(0.0, 1.0, 0.01) var apple_drop_chance_on_hit: float = 0.25
@export var destroy_min_apples: int = 1
@export var destroy_max_apples: int = 2
@export var apple_spawn_radius: float = 18.0


func _handle_damage_callback(damage_data: DamageData):
	super._handle_damage_callback(damage_data)
	if damage_data == null or damage_data.final_damage <= 0.0 or is_dead:
		return

	if randf() <= apple_drop_chance_on_hit:
		spawn_pickup_scene(apple_pickup_scene, 1, apple_spawn_radius)


func _die() -> void:
	if is_dead:
		return

	var safe_min_count: int = max(destroy_min_apples, 0)
	var safe_max_count: int = max(destroy_max_apples, safe_min_count)
	var apple_count: int = randi_range(safe_min_count, safe_max_count)
	spawn_pickup_scene(apple_pickup_scene, apple_count, apple_spawn_radius)
	super._die()
