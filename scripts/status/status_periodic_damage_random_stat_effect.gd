class_name StatusPeriodicDamageRandomStatEffect
extends StatusEffect

## 周期性造成伤害，并在每次跳伤时附加一个“持续到战斗结束”的随机属性惩罚。
## 当前用于“流血”：每 5 秒受到层数对应的物理伤害，并随机一级属性 -1。

const DEFAULT_PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

@export var damage_per_tick: float = 1.0
@export var tick_interval: float = 5.0
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var damage_tags: Array[String] = ["status", "bleed"]
@export var can_crit: bool = false

@export_group("Random Stat Penalty")
@export var random_primary_stats: Array[StringName] = DEFAULT_PRIMARY_STATS
@export var stat_penalty_per_tick: float = -1.0
@export var penalty_status_name: String = "流血虚弱"
@export_multiline var penalty_status_desc: String = "流血造成的临时属性削弱，持续到本场战斗结束。"
@export var penalty_status_icon: Texture2D

var tick_timers: Dictionary = {}
var penalty_counts: Dictionary = {}


func on_tick(instance: StatusInstance, delta: float) -> void:
	if instance == null or not (instance.target is Entity):
		return

	var key: String = instance.get_effect_key()
	var timer: float = float(tick_timers.get(key, 0.0)) + delta
	if timer < tick_interval:
		tick_timers[key] = timer
		return

	tick_timers[key] = 0.0
	var target: Entity = instance.target as Entity
	_apply_periodic_damage(instance, target)
	_apply_random_stat_penalty(instance, target, key)


func on_remove(instance: StatusInstance) -> void:
	if instance == null:
		return

	var key: String = instance.get_effect_key()
	tick_timers.erase(key)
	penalty_counts.erase(key)


func _apply_periodic_damage(instance: StatusInstance, target: Entity) -> void:
	if damage_per_tick <= 0.0:
		return

	var source_entity: Entity = _get_valid_source(instance)
	var damage_data: DamageData = DamageData.create(
		damage_per_tick * float(instance.stacks),
		damage_types,
		damage_tags,
		source_entity,
		target,
		can_crit
	)
	target.apply_damage(damage_data)


func _apply_random_stat_penalty(instance: StatusInstance, target: Entity, key: String) -> void:
	if stat_penalty_per_tick == 0.0 or random_primary_stats.is_empty():
		return
	if target == null or target.get_status_controller() == null:
		return

	var stat_name: StringName = _pick_random_stat()
	if stat_name == &"":
		return

	var count: int = int(penalty_counts.get(key, 0)) + 1
	penalty_counts[key] = count

	var status_data: StatusData = _build_penalty_status(key, count, stat_name)
	var source_key: String = "%s_penalty_%s" % [key, count]
	target.get_status_controller().add_status(status_data, instance.source, source_key, 1)


func _build_penalty_status(key: String, count: int, stat_name: StringName) -> StatusData:
	var stat_effect: StatusAddStatEffect = StatusAddStatEffect.new()
	stat_effect.stat_name = stat_name
	stat_effect.value_per_stack = stat_penalty_per_tick

	var status_data: StatusData = StatusData.new()
	status_data.id = StringName("%s_%s_penalty_%s" % [key, String(stat_name), count])
	status_data.status_name = "%s：%s" % [penalty_status_name, _get_primary_stat_display_name(stat_name)]
	status_data.desc = "%s：%s %s" % [penalty_status_desc, _get_primary_stat_display_name(stat_name), str(stat_penalty_per_tick)]
	status_data.icon = penalty_status_icon
	status_data.duration = -1.0
	status_data.max_stacks = 1
	status_data.stack_mode = StatusData.StackMode.REPLACE
	status_data.refresh_duration_on_reapply = false
	status_data.effects = [stat_effect]
	return status_data


func _pick_random_stat() -> StringName:
	if random_primary_stats.is_empty():
		return &""

	var index: int = randi_range(0, random_primary_stats.size() - 1)
	return random_primary_stats[index]


func _get_valid_source(instance: StatusInstance) -> Entity:
	if instance == null or instance.source == null:
		return null
	if not is_instance_valid(instance.source):
		return null
	if instance.source is Entity:
		return instance.source as Entity
	return null


func _get_primary_stat_display_name(stat_name: StringName) -> String:
	match stat_name:
		&"strength":
			return "力量"
		&"dexterity":
			return "敏捷"
		&"intelligence":
			return "智力"
		&"constitution":
			return "体质"
		&"speed":
			return "速度"
		&"charm":
			return "魅力"
		&"luck":
			return "幸运"
		_:
			return String(stat_name)
