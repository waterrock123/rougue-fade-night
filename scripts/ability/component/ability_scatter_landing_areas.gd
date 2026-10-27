## 在当前 AI 目标附近锁定多个落点，生成抛射领域；落点不追踪玩家。
## 数量、散布和二阶段增量均可调，领域伤害/状态由 manifest 自己处理。
class_name AbilityScatterLandingAreas
extends AbilityComponent

@export var manifest_scene: PackedScene
@export var count: int = 3
@export var phase_two_extra_count: int = 1
@export var scatter_radius: float = 75.0


func _activate(context: AbilityContext) -> void:
	if manifest_scene == null or not context.caster is Enemy:
		return
	var target: Entity = (context.caster as Enemy).current_target
	if not is_instance_valid(target):
		return
	var center: Vector2 = target.global_position
	var total: int = count
	if context.caster.has_method("get_encounter_phase") and context.caster.call("get_encounter_phase") == 2:
		total += phase_two_extra_count
	var map: BattleMap = get_tree().get_first_node_in_group("battle_map") as BattleMap
	var reserved: Array[Vector2] = []
	var angle: float = randf() * TAU
	for index: int in range(total):
		var offset: Vector2 = Vector2.ZERO if index == 0 else Vector2.RIGHT.rotated(angle + TAU * float(index - 1) / float(maxi(total - 1, 1))) * scatter_radius
		var point: Variant = center + offset
		if map != null:
			point = map.get_nearest_playable_position(point, 3, 0, reserved, 45.0)
		if not point is Vector2:
			continue
		reserved.append(point)
		_spawn(context, point)


func _spawn(context: AbilityContext, point: Vector2) -> void:
	var node: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if node == null:
		return
	context.caster.get_parent().add_child(node)
	node.global_position = context.caster.global_position
	var flight: AbilityContext = AbilityContext.new(context.caster, context.ability)
	flight.caster_action_version = context.caster_action_version
	flight.element_tags = context.element_tags.duplicate()
	flight.cast_record = context.cast_record
	flight.targets = [point]
	node.activate(flight)
