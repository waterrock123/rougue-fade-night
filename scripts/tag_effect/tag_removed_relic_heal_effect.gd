## 套装效果：指定 tag 的遗物被使用、出售或销毁时，为玩家恢复生命值。
class_name TagRemovedRelicHealEffect
extends TagEffect

@export var heal_amount: float = 1.0
@export var valid_reasons: Array[String] = ["used", "sold", "destroyed", "consumed"]

var active_contexts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	if not EventBus.relic_removed.is_connected(_on_relic_removed):
		EventBus.relic_removed.connect(_on_relic_removed)


func on_deactivate(context: TagEffectContext) -> void:
	active_contexts.erase(TagEffectRuntimeHelper.get_context_key(context))
	if active_contexts.is_empty() and EventBus.relic_removed.is_connected(_on_relic_removed):
		EventBus.relic_removed.disconnect(_on_relic_removed)


func _on_relic_removed(relic: Relic, reason: String) -> void:
	if relic == null or not valid_reasons.has(reason):
		return
	if not TagEffectRuntimeHelper.relic_has_tag(relic, tag):
		return

	for value in active_contexts.values():
		var context := value as TagEffectContext
		if context != null:
			if reason == "used" and TagEffectRuntimeHelper.get_owner_entity(context) == null:
				continue
			_heal_context_owner(context)


func _heal_context_owner(context: TagEffectContext) -> void:
	if heal_amount <= 0.0:
		return

	var max_health := context.stats_controller.get_stat(&"max_health") if context.stats_controller != null else 0.0
	var owner_entity := TagEffectRuntimeHelper.get_owner_entity(context)
	if owner_entity != null:
		var entity_max_health := max_health if max_health > 0.0 else owner_entity.max_health
		owner_entity.current_health = min(owner_entity.current_health + heal_amount, entity_max_health)
		if context.stats_controller != null:
			context.stats_controller.current_health = owner_entity.current_health
			context.stats_controller.sync_runtime_resources()
		if owner_entity.is_in_group("player"):
			EventBus.player_health_changed.emit(owner_entity.current_health, entity_max_health)
		return

	if context.player_build != null:
		if max_health <= 0.0:
			context.player_build.current_health += heal_amount
		else:
			context.player_build.current_health = min(context.player_build.current_health + heal_amount, max_health)
		if context.stats_controller != null:
			context.stats_controller.current_health = context.player_build.current_health
			context.stats_controller.sync_runtime_resources()
		EventBus.player_health_changed.emit(context.player_build.current_health, max_health)
