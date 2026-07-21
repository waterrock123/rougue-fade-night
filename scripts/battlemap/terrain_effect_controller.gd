class_name TerrainEffectController
extends Node

## 战斗地形规则结算器。
## 它只负责“规则层”：读取 BattleMap 的瓦片 custom data，并把状态/伤害应用到站在地形上的实体。
## 视觉层仍然由 TileMapLayer、manifest 或后续 VFX 节点负责，这样规则和表现不会互相绑死。

@export_group("检测目标")
## 会受到地形规则影响的实体组。召唤物属于 player_ally，但这里直接用 summon_pet 避免重复扫描 UI/其他友军节点。
@export var affected_groups: Array[StringName] = [&"player", &"enemy", &"summon_pet"]
## 多久结算一次地形。伤害会按实际经过时间折算，状态会走单独的刷新间隔。
@export var tick_interval: float = 0.35
## 战斗未正式开始时不结算，避免进场初始化阶段误触发地形效果。
@export var require_battle_active: bool = true

@export_group("状态")
## 瓦片 status_id 对应的资源目录。默认支持 res://status/burn.tres 这种按 id 命名的资源。
@export var status_resource_dirs: Array[String] = ["res://status"]
## 同一个实体站在同一种地形状态上时，至少间隔多久才会再次施加/刷新状态。
@export var status_apply_interval: float = 1.0
## 地形状态默认层数。需要更复杂的“每种地形不同层数”时，后续可以再扩展 custom data。
@export var default_status_stacks: int = 1

@export_group("直接伤害")
## 是否启用 damage_per_second。普通火焰地面建议只填 status_id=burn，不填直接伤害，避免双重伤害。
@export var enable_direct_damage: bool = true
@export var direct_damage_can_crit: bool = false

var battle_map: BattleMap
var paused: bool = false
var tick_timer: float = 0.0
var status_cache: Dictionary = {}
var status_last_apply_time: Dictionary = {}


func _ready() -> void:
	add_to_group("terrain_effect_controller")
	if EventBus != null and not EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.connect(_handle_game_pause)


func _exit_tree() -> void:
	if EventBus != null and EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.disconnect(_handle_game_pause)


func bind_battle_map(new_battle_map: BattleMap) -> void:
	battle_map = new_battle_map


func _process(delta: float) -> void:
	if paused:
		return
	if require_battle_active and EventBus != null and not EventBus.is_battle_active:
		return

	if battle_map == null:
		battle_map = get_tree().get_first_node_in_group("battle_map") as BattleMap
	if battle_map == null:
		return

	tick_timer += delta
	if tick_timer < tick_interval:
		return

	var elapsed_time: float = tick_timer
	tick_timer = 0.0
	_apply_terrain_effects(elapsed_time)


func _apply_terrain_effects(elapsed_time: float) -> void:
	for entity: Entity in _collect_affected_entities():
		_apply_effect_to_entity(entity, elapsed_time)


func _apply_effect_to_entity(entity: Entity, elapsed_time: float) -> void:
	if entity == null or not is_instance_valid(entity) or entity.is_dead:
		return

	var terrain_type: StringName = battle_map.get_terrain_type(entity.global_position, &"")
	var damage_per_second: float = battle_map.get_damage_per_second(entity.global_position, 0.0)
	var status_id: StringName = battle_map.get_status_id(entity.global_position, &"")

	if status_id != &"":
		_apply_status_from_terrain(entity, status_id)

	if enable_direct_damage and damage_per_second > 0.0:
		_apply_direct_damage_from_terrain(entity, terrain_type, damage_per_second * elapsed_time)


func _apply_status_from_terrain(entity: Entity, status_id: StringName) -> void:
	var status_data: StatusData = _get_status_data(status_id)
	if status_data == null:
		return

	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var cooldown_key: String = "%s:%s" % [entity.get_instance_id(), String(status_id)]
	var last_time: float = float(status_last_apply_time.get(cooldown_key, -INF))
	if now_seconds - last_time < max(status_apply_interval, 0.0):
		return

	var status_controller: StatusController = entity.get_status_controller()
	if status_controller == null:
		return

	status_last_apply_time[cooldown_key] = now_seconds
	var source_key: String = "terrain_%s" % String(status_id)
	status_controller.add_status(status_data, self, source_key, max(default_status_stacks, 1))


func _apply_direct_damage_from_terrain(entity: Entity, terrain_type: StringName, damage_amount: float) -> void:
	if damage_amount <= 0.0:
		return

	var tags: Array[String] = ["terrain", "battle_map"]
	if terrain_type != &"":
		tags.append(String(terrain_type))

	var damage_data: DamageData = DamageData.create(
		damage_amount,
		_get_damage_types_for_terrain(terrain_type),
		tags,
		null,
		entity,
		direct_damage_can_crit
	)
	entity.apply_damage(damage_data)


func _collect_affected_entities() -> Array[Entity]:
	var result: Array[Entity] = []
	var seen_ids: Dictionary = {}

	for group_name: StringName in affected_groups:
		for node in get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var entity: Entity = node as Entity
			if entity.is_dead:
				continue

			var instance_id: int = entity.get_instance_id()
			if seen_ids.has(instance_id):
				continue

			seen_ids[instance_id] = true
			result.append(entity)

	return result


func _get_status_data(status_id: StringName) -> StatusData:
	if status_id == &"":
		return null
	if status_cache.has(status_id):
		return status_cache.get(status_id) as StatusData

	var status_data: StatusData = _load_status_data(status_id)
	status_cache[status_id] = status_data
	return status_data


func _load_status_data(status_id: StringName) -> StatusData:
	var file_name: String = "%s.tres" % String(status_id)
	for dir_path: String in status_resource_dirs:
		var direct_path: String = "%s/%s" % [dir_path.trim_suffix("/"), file_name]
		if ResourceLoader.exists(direct_path):
			var direct_resource: Resource = ResourceLoader.load(direct_path)
			if direct_resource is StatusData:
				return direct_resource as StatusData

	for dir_path: String in status_resource_dirs:
		var found_status: StatusData = _scan_status_dir(dir_path, status_id)
		if found_status != null:
			return found_status

	push_warning("TerrainEffectController 找不到 status_id 对应资源: %s" % String(status_id))
	return null


func _scan_status_dir(dir_path: String, status_id: StringName) -> StatusData:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return null

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			file_name = dir.get_next()
			continue

		var resource_path: String = "%s/%s" % [dir_path.trim_suffix("/"), file_name]
		var resource: Resource = ResourceLoader.load(resource_path)
		if resource is StatusData and (resource as StatusData).id == status_id:
			dir.list_dir_end()
			return resource as StatusData

		file_name = dir.get_next()

	dir.list_dir_end()
	return null


func _get_damage_types_for_terrain(terrain_type: StringName) -> Array[int]:
	match terrain_type:
		&"fire", &"burn", &"lava":
			return [DamageData.DamageType.FIRE]
		&"ice", &"frost", &"snow":
			return [DamageData.DamageType.ICE]
		&"poison", &"toxic":
			return [DamageData.DamageType.POISON]
		&"lightning", &"electric":
			return [DamageData.DamageType.LIGHTNING]
		_:
			return [DamageData.DamageType.PHYSICAL]


func _handle_game_pause(is_paused: bool) -> void:
	paused = is_paused
