## 定点圆形脉冲：伤害、首次延迟、跳数、末跳状态独立配置。
## 不依赖Area2D进入信号，生成当帧也能命中；用于冰环、雷阵和延迟爆破。
class_name TimedRadialAreaManifest
extends AbilityManifest

@export var radius: float = 80.0
@export var pulse_count: int = 1
@export var pulse_interval: float = 1.0
@export var initial_delay: float = 0.0
@export var damage: float = 20.0
@export var damage_types: Array[int] = []
@export var scaling_rule: DamageScalingRule
@export var poise_damage: float = 4.0
@export var hit_status: StatusData
@export var status_stacks: int = 1
@export var status_duration: float = INF
@export_range(0.0, 1.0) var status_chance: float = 1.0
@export var status_only_last_pulse: bool = false
@export var area_color: Color = Color(0.5, 0.85, 1.0, 0.65)
## 正式贴图接入后可关闭实心填充，保留准确范围的细边线；不改变命中范围。
@export var draw_area_fill: bool = true
var source: Entity
var ability_id: StringName
var slot_index: int = -1
var elapsed: float = 0.0
var emitted: int = 0
var next_pulse: float = 0.0
var active: bool = false
var pulse_glow: float = 0.0


func _activate(context: AbilityContext) -> void:
	source = context.caster
	ability_id = context.ability.id if is_instance_valid(context.ability) else &""
	slot_index = context.ability.runtime_slot_index if is_instance_valid(context.ability) else -1
	next_pulse = maxf(initial_delay, 0.0)
	active = true
	_advance(0.0)


func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(source) or source.is_dead or not EventBus.is_battle_active:
		queue_free()
		return
	_advance(delta)
	pulse_glow = maxf(pulse_glow - delta * 3.0, 0.0)
	queue_redraw()


func _advance(delta: float) -> void:
	elapsed += delta
	while emitted < maxi(pulse_count, 1) and elapsed >= next_pulse:
		emitted += 1
		_apply_pulse()
		pulse_glow = 1.0
		next_pulse += maxf(pulse_interval, 0.05)
	if emitted >= maxi(pulse_count, 1) and elapsed >= next_pulse - maxf(pulse_interval, 0.05) + 0.3:
		queue_free()


func _apply_pulse() -> void:
	for candidate: Variant in SkillCombatQuery.enemies_within(source, global_position, radius):
		if not is_instance_valid(source) or source.is_dead or not EventBus.is_battle_active:
			return
		if not is_instance_valid(candidate) or candidate.is_dead:
			continue
		var target: Entity = candidate as Entity
		var data: DamageData = DamageData.create(damage, damage_types, ["skill", "aoe"], source, target, true, scaling_rule, ability_id, slot_index, poise_damage)
		stamp_damage_elements(data)
		target.apply_damage(data)
		_apply_status(target, data)


func _apply_status(target: Entity, data: DamageData) -> void:
	if hit_status == null or (status_only_last_pulse and emitted != maxi(pulse_count, 1)):
		return
	if not is_instance_valid(target) or target.is_dead or data.is_miss or data.final_damage <= 0.0:
		return
	if is_instance_valid(target.status_controller) and randf() < status_chance:
		target.status_controller.add_status(hit_status, source, "area_%s_%s" % [ability_id, hit_status.id], status_stacks, status_duration)


func _draw() -> void:
	if not active:
		return
	var color: Color = area_color
	color.a *= 0.12 + pulse_glow * 0.25
	if draw_area_fill:
		draw_circle(Vector2.ZERO, radius, color)
	color.a = area_color.a * (0.3 + pulse_glow * 0.7)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 1.0, true)
