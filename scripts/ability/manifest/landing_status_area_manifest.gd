## 抛射落地领域：飞行过程中不伤害；落地只伤害一次，随后只定时施加状态。
## VisualPivot/Sprite2D 留空给美术，支持拋物线和领域渐隐，不使用碰撞回调生成节点。
class_name LandingStatusAreaManifest
extends AbilityManifest

@export var flight_time: float = 0.8
@export var arc_height: float = 65.0
@export var radius: float = 38.0
@export var damage: float = 16.0
@export var damage_types: Array[int] = [DamageData.DamageType.POISON]
@export var target_group: StringName = &"player"
@export var area_duration: float = 4.0
@export var status_interval: float = 0.3
@export var status_data: StatusData
@export var status_duration: float = 0.7

var action: AbilityContext
var source: Entity
var start_position: Vector2
var target_position: Vector2
var elapsed: float = 0.0
var landed: bool = false
var tick_remaining: float = 0.0
@onready var visual_pivot: Node2D = $VisualPivot
@onready var area_visual: Node2D = $AreaVisual


func activate(context: AbilityContext) -> void:
	capture_element_tags(context)
	action = context
	source = context.caster
	start_position = global_position
	target_position = context.get_target_positon(0) if not context.targets.is_empty() else start_position
	EncounterWarning.spawn(context, target_position, radius, flight_time)


func _process(delta: float) -> void:
	if action == null or not is_instance_valid(source) or source.is_dead:
		queue_free()
		return
	if not landed and not action.is_caster_action_valid():
		queue_free()
		return
	elapsed += delta
	if not landed:
		var progress: float = clampf(elapsed / maxf(flight_time, 0.01), 0.0, 1.0)
		global_position = start_position.lerp(target_position, progress)
		visual_pivot.position.y = -sin(progress * PI) * arc_height
		if progress >= 1.0:
			_land()
		return
	tick_remaining -= delta
	if tick_remaining <= 0.0:
		tick_remaining = maxf(status_interval, 0.05)
		_apply_to_targets(false)
	area_visual.modulate.a = clampf((area_duration - elapsed) / 0.8, 0.0, 1.0)
	if elapsed >= area_duration:
		queue_free()


func _land() -> void:
	landed = true
	elapsed = 0.0
	visual_pivot.visible = false
	area_visual.visible = true
	# 淡色圆仅表示危险规则范围；领域的正式动画由 AreaVisual/Sprite2D 补充。
	var marker: EncounterWarning = EncounterWarning.spawn(action, global_position, radius, area_duration)
	marker.persist_after_action = true
	marker.color = Color(0.65, 0.8, 0.3, 0.12)
	marker.reparent(area_visual)
	_apply_to_targets(true)


func _apply_to_targets(with_damage: bool) -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform.origin = global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen: Dictionary = {}
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 128):
		if not is_instance_valid(source) or source.is_dead:
			return
		var collider: Node = result.get("collider") as Node
		var target: Entity = collider.get_parent() as Entity if is_instance_valid(collider) else null
		if not is_instance_valid(target) or seen.has(target.get_instance_id()):
			continue
		if not target.can_be_targeted() or not target.matches_target_group(target_group):
			continue
		seen[target.get_instance_id()] = true
		if with_damage:
			var data: DamageData = DamageData.create(damage, damage_types, ["skill", "thrown", "aoe"], source, target, false, null, action.ability.id)
			stamp_damage_elements(data)
			target.apply_damage(data)
		if is_instance_valid(target) and not target.is_dead and target.status_controller != null and status_data != null:
			target.status_controller.add_status(status_data, source, "landing_%d" % get_instance_id(), 1, status_duration)
