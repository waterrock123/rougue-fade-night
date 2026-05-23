class_name ThrownArcImpactManifest
extends AbilityManifest

@export_group("抛射")
## 抛射飞行总时长。数值越小，雪球落地越快。
@export var flight_time: float = 0.45
## 视觉节点最高会向上抬起的高度，用来制造抛物线效果。
@export var arc_height: float = 56.0
## 最大投掷距离，鼠标点超过该距离时会被限制在这个范围内。
@export var max_range: float = 60
## 落地后要命中的目标组。玩家使用的消耗品通常填 enemy。
@export var target_group: String = "enemy"
## 落地后释放节点前等待的时间，方便播放简单的落地视觉效果。
@export var free_delay_after_impact: float = 0.08
## 飞行时是否让视觉贴图轻微旋转，提升抛射感。
@export var rotate_visual: bool = true
@export var visual_rotate_speed: float = 12.0

@export_group("伤害")
## 落地爆开的基础伤害。升级版可以通过 UseSpawnManifestEffect 覆盖这个值。
@export var damage: float = 40.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL, DamageData.DamageType.ICE]
@export var tags: Array[String] = ["relic", "consumable", "thrown", "aoe"]
@export var scaling_rule: DamageScalingRule

@export_group("落地状态")
## 落地命中时附加的状态，比如雪球使用的 frost_slow。
@export var impact_status: StatusData
@export var impact_status_stacks: int = 1
## 状态持续时间覆盖。INF 表示使用 StatusData 自己的默认 duration。
@export var impact_status_duration_override: float = INF

@onready var visual_pivot: Node2D = get_node_or_null("VisualPivot") as Node2D
@onready var projectile_sprite: Sprite2D = get_node_or_null("VisualPivot/Sprite2D") as Sprite2D
@onready var shadow_sprite: Sprite2D = get_node_or_null("VisualPivot/Shadow") as Sprite2D
@onready var impact_area: Area2D = get_node_or_null("ImpactArea") as Area2D
@onready var impact_vfx: Node2D = get_node_or_null("ImpactVFX") as Node2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var _start_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _elapsed_time: float = 0.0
var _has_impacted: bool = false


func _ready() -> void:
	_setup_shadow()


## 接收 UseSpawnManifestEffect 或技能组件传入的目标点，开始抛射移动。
func activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		queue_free()
		return

	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1
	_start_position = global_position
	_target_position = _get_clamped_target_position(context)
	_elapsed_time = 0.0
	_has_impacted = false


func _process(delta: float) -> void:
	if _has_impacted:
		return
	if source != null and (not is_instance_valid(source) or source.is_dead):
		queue_free()
		return

	_elapsed_time += delta
	var progress := _get_progress()
	_update_ground_position(progress)
	_update_visual_arc(progress, delta)

	if progress >= 1.0:
		_impact()


func _get_clamped_target_position(context: AbilityContext) -> Vector2:
	var target_position = _start_position + Vector2.RIGHT * min(max_range, 80.0)
	if context.targets.size() > 0:
		target_position = context.get_target_positon(0)

	var offset = target_position - _start_position
	if max_range > 0.0 and offset.length() > max_range:
		target_position = _start_position + offset.normalized() * max_range
	return target_position


func _get_progress() -> float:
	if flight_time <= 0.0:
		return 1.0
	return clamp(_elapsed_time / flight_time, 0.0, 1.0)


## 根节点代表地面落点位置；碰撞区域跟着根节点走，落地时直接读取范围内目标。
func _update_ground_position(progress: float) -> void:
	global_position = _start_position.lerp(_target_position, progress)


## 视觉节点单独向上偏移，形成“抛出去”的假 3D 高度。
func _update_visual_arc(progress: float, delta: float) -> void:
	if visual_pivot == null:
		return

	var height := sin(progress * PI) * arc_height
	visual_pivot.position = Vector2(0.0, -height)

	if rotate_visual and projectile_sprite != null:
		projectile_sprite.rotation += visual_rotate_speed * delta

	if shadow_sprite != null:
		var shadow_alpha = lerp(0.25, 0.08, height / max(arc_height, 1.0))
		var shadow_scale = lerp(1.0, 0.65, height / max(arc_height, 1.0))
		shadow_sprite.modulate.a = shadow_alpha
		shadow_sprite.scale = Vector2.ONE * shadow_scale


func _impact() -> void:
	if _has_impacted:
		return

	_has_impacted = true
	if visual_pivot != null:
		visual_pivot.position = Vector2.ZERO
	_play_impact_feedback()

	# 等待一次物理帧，确保 ImpactArea 已经在落点位置刷新重叠列表。
	await get_tree().physics_frame
	_damage_targets_in_area()
	await get_tree().create_timer(max(free_delay_after_impact, 0.0)).timeout
	queue_free()


func _damage_targets_in_area() -> void:
	if impact_area == null:
		return

	var damaged_entities: Array[Entity] = []
	for area in impact_area.get_overlapping_areas():
		var entity := _get_target_entity_from_area(area)
		if entity == null or damaged_entities.has(entity):
			continue

		damaged_entities.append(entity)
		_apply_damage_to_entity(entity)
		_apply_status_to_entity(entity)


func _get_target_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent := area.get_parent()
	if parent == null or not parent.is_in_group(target_group):
		return null
	if not (parent is Entity):
		return null

	var entity := parent as Entity
	if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
		return null
	return entity


func _apply_damage_to_entity(entity: Entity) -> void:
	var valid_source := _get_valid_source()
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		valid_source,
		entity,
		can_crit,
		scaling_rule,
		source_ability_id,
		source_ability_slot_index
	)
	entity.apply_damage(damage_data)


func _apply_status_to_entity(entity: Entity) -> void:
	if impact_status == null:
		return

	var status_controller := entity.get_status_controller()
	if status_controller == null:
		status_controller = entity.get_node_or_null("StatusController") as StatusController
	if status_controller == null:
		return

	status_controller.add_status(
		impact_status,
		_get_valid_source(),
		"%s_%s" % [impact_status.id, get_instance_id()],
		impact_status_stacks,
		impact_status_duration_override
	)


func _play_impact_feedback() -> void:
	if projectile_sprite != null:
		projectile_sprite.visible = false
	if shadow_sprite != null:
		shadow_sprite.visible = false
	if impact_vfx != null:
		impact_vfx.visible = true


func _setup_shadow() -> void:
	if projectile_sprite == null or shadow_sprite == null:
		return

	shadow_sprite.texture = projectile_sprite.texture
	shadow_sprite.position = Vector2(0.0, 8.0)
	shadow_sprite.scale = Vector2(1.0, 0.35)
	shadow_sprite.modulate = Color(0.0, 0.0, 0.0, 0.22)
	shadow_sprite.z_index = -1


func _get_valid_source() -> Entity:
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source
