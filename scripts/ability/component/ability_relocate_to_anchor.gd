## 从预设驻扎点选择安全落点，提前预警后迁移。只负责位置与显隐，不造成伤害。
## 要求地图可达、实体完整碰撞体不压墙、远离盟友、与当前位置有足够间距。
class_name AbilityRelocateToAnchor
extends AbilityComponent

@export var warning_duration: float = 1.0
@export var minimum_player_distance: float = 150.0
@export var minimum_relocation_distance: float = 90.0
@export var clearance_cells: int = 2
@export var footprint_radius: float = 30.0
@export var visual_path: NodePath = NodePath("AnimatedSprite2D")
@export var reappear_duration: float = 0.35
@export_flags_2d_physics var world_mask: int = 1
var visual: CanvasItem
var visual_color: Color = Color.WHITE
var visual_tween: Tween
var active_action: AbilityContext


func _activate(context: AbilityContext) -> void:
	if not context.caster.has_method("get_relocation_candidates"):
		return
	var candidates: Array = context.caster.call("get_relocation_candidates")
	candidates.shuffle()
	var destination: Variant = null
	for value: Variant in candidates:
		if value is Vector2 and is_candidate_safe(context.caster, value):
			destination = value
			break
	if not destination is Vector2:
		return
	active_action = context
	EncounterWarning.spawn(context, destination, footprint_radius + 20.0, warning_duration)
	visual = context.caster.get_node_or_null(visual_path) as CanvasItem
	if visual != null:
		visual_color = visual.modulate
		visual_tween = create_tween()
		visual_tween.tween_property(visual, "modulate:a", 0.0, warning_duration)
	await get_tree().create_timer(warning_duration, false).timeout
	if not is_inside_tree() or not context.is_caster_action_valid():
		_restore_visual()
		return
	# 移动前再次检查玩家/动态障碍，避免预警期间玩家跑到落点而被压住。
	if is_candidate_safe(context.caster, destination):
		context.caster.global_position = destination
		if context.caster.has_method("set_anchor_position"):
			context.caster.call("set_anchor_position", destination)
		context.caster.clear_terrain_motion_velocity()
	_reappear()


func _process(_delta: float) -> void:
	if active_action != null and not active_action.is_caster_action_valid():
		_restore_visual()


func _reappear() -> void:
	if is_instance_valid(visual):
		visual_tween = create_tween()
		visual_tween.tween_property(visual, "modulate", visual_color, reappear_duration)
		visual_tween.tween_callback(_restore_visual)
	else:
		active_action = null


func is_candidate_safe(caster: Entity, point: Vector2) -> bool:
	if caster.global_position.distance_to(point) < minimum_relocation_distance:
		return false
	var map: BattleMap = caster.get_tree().get_first_node_in_group("battle_map") as BattleMap
	if map != null and not map.is_world_position_in_playable_region(point, clearance_cells):
		return false
	for group: StringName in [&"player", &"player_ally", &"summon_pet"]:
		for node: Node in caster.get_tree().get_nodes_in_group(group):
			if node is Entity and not node.is_dead and node.global_position.distance_to(point) < minimum_player_distance:
				return false
	return is_footprint_clear(caster, point)


func is_footprint_clear(caster: Entity, point: Vector2) -> bool:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = footprint_radius
	query.shape = shape
	query.transform.origin = point
	query.collision_mask = world_mask
	query.collide_with_areas = false
	query.exclude = [caster.get_rid()]
	return caster.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _restore_visual() -> void:
	if visual_tween != null and visual_tween.is_valid():
		visual_tween.kill()
	visual_tween = null
	if is_instance_valid(visual):
		visual.modulate = visual_color
	visual = null
	active_action = null


func _exit_tree() -> void:
	_restore_visual()
