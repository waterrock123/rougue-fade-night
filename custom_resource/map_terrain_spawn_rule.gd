class_name MapTerrainSpawnRule
extends Resource

## 单种特殊地形的随机生成规则。
## 例如 fire 使用 EffectLayer 的火海瓦片，ice_ground 后续可以配置成冰面瓦片。

@export var enabled: bool = true
@export var terrain_id: StringName = &""

@export_group("瓦片")
@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0

@export_group("生成数量")
## 每个 TERRAIN 区域是否触发这条规则。
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var min_count_per_area: int = 0
@export var max_count_per_area: int = 0
@export var max_attempts_per_area: int = 80
## 预留给后续“额外权重抽地形”使用，目前最小闭环只按每条规则逐区域生成。
@export var weight: float = 1.0

@export_group("位置规则")
## 留空代表所有 TERRAIN 区域都可以生成；填写后只在 area_id 匹配的区域生成。
@export var allowed_area_ids: Array[StringName] = []
@export var require_walkable: bool = true
@export var overwrite_existing_effect_tiles: bool = false


func is_valid_rule() -> bool:
	return enabled and terrain_id != &"" and max_count_per_area >= 0


func can_spawn_in_area(area: BattleMapRandomArea) -> bool:
	if area == null or not area.enabled:
		return false
	if not area.matches_area_type(BattleMapRandomArea.AreaType.TERRAIN):
		return false
	if allowed_area_ids.is_empty():
		return true
	return allowed_area_ids.has(area.area_id)


func roll_count(max_available_cells: int) -> int:
	if not is_valid_rule() or max_available_cells <= 0:
		return 0
	if RunRng.randf() > clamp(chance, 0.0, 1.0):
		return 0

	var safe_min_count: int = max(min_count_per_area, 0)
	var safe_max_count: int = max(max_count_per_area, safe_min_count)
	if safe_max_count <= 0:
		return 0

	var rolled_count: int = RunRng.randi_range(safe_min_count, safe_max_count)
	return clampi(rolled_count, 0, max_available_cells)
