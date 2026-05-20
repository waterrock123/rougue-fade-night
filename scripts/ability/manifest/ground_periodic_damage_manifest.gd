## 地面持续伤害 Manifest。
## 生成后停留在原地，按固定间隔检查 Area2D 上的目标并造成伤害，生命周期结束前渐隐消失。
class_name GroundPeriodicDamageManifest
extends AbilityManifest

@export_group("Lifetime")
@export var lifetime: float = 3.0
@export var fade_duration: float = 0.8

@export_group("Hit Check")
@export var target_group: StringName = &"enemy"
@export var tick_interval: float = 1.0
@export var damage_on_spawn: bool = false

@export_group("Damage")
@export var damage: float = 2.0
@export var can_crit: bool = false
@export var damage_types: Array[int] = [DamageData.DamageType.ICE]
@export var tags: Array[String] = ["ground", "frost_trail"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
@export var tick_sound: AudiioConfig

@export_group("Status")
## 每次造成伤害时顺便施加的状态，可为空。雪暴瓶可用它施加短暂减速。
@export var on_tick_status: StatusData
@export var on_tick_status_stacks: int = 1

@onready var hit_area: Area2D = get_node_or_null("Area2D") as Area2D
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var elapsed_time: float = 0.0
var tick_timer: float = 0.0
var fade_started: bool = false


func _ready() -> void:
	if animated_sprite != null:
		animated_sprite.play()


func activate(context: AbilityContext) -> void:
	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1

	if damage_on_spawn:
		_apply_tick()


func _process(delta: float) -> void:
	elapsed_time += delta
	tick_timer += delta

	if source != null and (not is_instance_valid(source) or source.is_dead):
		queue_free()
		return

	if tick_timer >= tick_interval:
		tick_timer = 0.0
		_apply_tick()

	if not fade_started and elapsed_time >= max(lifetime - fade_duration, 0.0):
		_start_fade()

	if elapsed_time >= lifetime:
		queue_free()


func _apply_tick() -> void:
	if hit_area == null:
		return

	var valid_source := _get_valid_source()
	if source != null and valid_source == null:
		queue_free()
		return

	var damaged_targets: Array[Entity] = []
	for area in hit_area.get_overlapping_areas():
		var target := _get_entity_from_area(area)
		if target == null or damaged_targets.has(target):
			continue

		_damage_target(target, valid_source)
		_apply_status_to_target(target, valid_source)
		damaged_targets.append(target)

	if not damaged_targets.is_empty() and tick_sound != null:
		AudioController.play(tick_sound, global_position)


func _damage_target(target: Entity, valid_source: Entity) -> void:
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		valid_source,
		target,
		can_crit,
		scaling_rule,
		source_ability_id,
		source_ability_slot_index
	)
	target.apply_damage(damage_data)


func _apply_status_to_target(target: Entity, valid_source: Entity) -> void:
	if on_tick_status == null:
		return

	var status_controller := target.get_status_controller()
	if status_controller == null:
		return

	var source_key := "%s_%s" % [tags[0] if not tags.is_empty() else "ground_manifest", on_tick_status.id]
	status_controller.add_status(on_tick_status, valid_source, source_key, on_tick_status_stacks)


func _get_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent := area.get_parent()
	if not (parent is Entity):
		return null

	var entity := parent as Entity
	if target_group != &"" and not entity.is_in_group(String(target_group)):
		return null
	if source != null and is_instance_valid(source) and entity == source:
		return null
	if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
		return null

	return entity


func _get_valid_source() -> Entity:
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source


func _start_fade() -> void:
	fade_started = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, max(fade_duration, 0.01))
