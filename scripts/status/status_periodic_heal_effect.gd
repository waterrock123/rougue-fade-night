class_name StatusPeriodicHealEffect
extends StatusEffect

@export var heal_per_tick: float = 1.0
@export var tick_interval: float = 1.0

var tick_timers: Dictionary = {}


# 按固定间隔恢复生命，可用于整场战斗持续回血等状态。
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
	target.current_health = min(target.current_health + heal_per_tick * instance.stacks, target.max_health)
	if target.stats_controller != null:
		target.stats_controller.current_health = target.current_health
		target.stats_controller.sync_runtime_resources()
	EventBus.player_health_changed.emit(target.current_health, target.max_health)


func on_remove(instance: StatusInstance) -> void:
	if instance != null:
		tick_timers.erase(instance.get_effect_key())
