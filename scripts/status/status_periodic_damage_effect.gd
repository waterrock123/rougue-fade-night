class_name StatusPeriodicDamageEffect
extends StatusEffect

@export var damage_per_tick: float = 1.0
@export var tick_interval: float = 1.0
@export var damage_types: Array[int] = [DamageData.DamageType.POISON]

var tick_timers: Dictionary = {}


# 按固定间隔造成伤害，可用于流血、中毒、灼烧等状态。
func on_tick(instance: StatusInstance, delta: float) -> void:
	if instance == null or not (instance.target is Entity):
		return

	var key := instance.get_effect_key()
	var timer := float(tick_timers.get(key, 0.0)) + delta
	if timer < tick_interval:
		tick_timers[key] = timer
		return

	tick_timers[key] = 0.0
	var target := instance.target as Entity
	var damage_data := DamageData.create(
		damage_per_tick * instance.stacks,
		damage_types,
		["status", String(instance.get_status_id())],
		instance.source as Entity,
		target,
		false
	)
	target.apply_damage(damage_data)


func on_remove(instance: StatusInstance) -> void:
	if instance != null:
		tick_timers.erase(instance.get_effect_key())
