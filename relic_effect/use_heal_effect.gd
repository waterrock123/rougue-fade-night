class_name UseHealEffect
extends RelicEffect

@export var heal_amount: float = 1.0


# 使用消耗品时恢复生命值。
# 治疗会被限制在最大生命值以内，并同步 StatsController 与玩家生命 UI。
func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if heal_amount <= 0.0:
		return

	var owner := relic_context.owner as Entity
	owner.current_health = min(owner.current_health + heal_amount, owner.max_health)

	if owner.stats_controller != null:
		owner.stats_controller.current_health = owner.current_health
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_health_changed.emit(owner.current_health, owner.max_health)
