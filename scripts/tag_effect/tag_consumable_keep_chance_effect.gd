## 套装效果：使用消耗品时，有概率不消耗本次使用的消耗品。
class_name TagConsumableKeepChanceEffect
extends TagEffect

@export_range(0.0, 1.0, 0.001) var keep_chance: float = 0.05

var active_keys: Array[String] = []


func on_activate(context: TagEffectContext) -> void:
	if context == null or context.run_stats == null:
		return

	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty() or active_keys.has(key):
		return

	active_keys.append(key)
	context.run_stats.set_consumable_keep_chance(key, keep_chance)


func on_deactivate(context: TagEffectContext) -> void:
	if context == null or context.run_stats == null:
		return

	var key := TagEffectRuntimeHelper.get_context_key(context)
	active_keys.erase(key)
	context.run_stats.clear_consumable_keep_chance(key)
