## 使用消耗品在周围生成实体，复用地图安全落点；仅负责生成，不规定阵营、AI或伤害。
## 默认不登记到EnemySpawner，所以额外实体不阻止关卡结束；实体随战斗场景清理。
class_name UseSpawnActorsEffect
extends RelicEffect

@export var actor_scene: PackedScene
@export_range(1, 20, 1) var spawn_count: int = 2
@export var spawn_radius: float = 72.0
@export var require_active_battle: bool = true
@export var safe_search_radius_cells: int = 8
@export var spawn_clearance_cells: int = 1
@export var minimum_separation: float = 24.0


func on_use(context: RelicContext, _effect_key: Variant) -> void:
	if actor_scene == null or context == null or not is_instance_valid(context.owner) or not context.owner is Entity:
		return
	# 拾取/碰撞信号可能正在刷新物理查询，整段生成延后，避免add_child激活碰撞区域时报错。
	_spawn.call_deferred(context.owner)


func _spawn(caster: Entity) -> void:
	if not is_instance_valid(caster) or caster.is_dead or not caster.is_inside_tree():
		return
	if require_active_battle and not EventBus.is_battle_active:
		return
	var parent: Node = caster.get_parent()
	var map: BattleMap = caster.get_tree().get_first_node_in_group("battle_map") as BattleMap
	var reserved: Array[Vector2] = [caster.global_position]
	var start_angle: float = randf() * TAU
	for index: int in range(spawn_count):
		var desired: Vector2 = caster.global_position + Vector2.RIGHT.rotated(start_angle + TAU * index / spawn_count) * spawn_radius
		var position: Variant = map.get_nearest_playable_position(desired, safe_search_radius_cells, spawn_clearance_cells, reserved, minimum_separation) if map != null else desired
		if not position is Vector2:
			continue
		var node: Node = actor_scene.instantiate()
		if not node is Entity:
			node.free()
			push_warning("UseSpawnActorsEffect要求根节点继承Entity。")
			return
		var actor: Entity = node as Entity
		actor.position = (parent as Node2D).to_local(position) if parent is Node2D else position
		parent.add_child(actor)
		reserved.append(position)
