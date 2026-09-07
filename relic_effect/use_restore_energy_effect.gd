class_name UseRestoreEnergyEffect
extends RelicEffect

## 使用消耗品时恢复固定数量的能量。
@export var energy_amount: float = 1.0


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return

	var owner: Entity = relic_context.owner as Entity
	if owner.is_dead or energy_amount <= 0.0:
		return

	owner.current_energy = min(owner.current_energy + energy_amount, owner.max_energy)
	if owner.stats_controller != null:
		owner.stats_controller.current_energy = owner.current_energy
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player") and EventBus != null:
		EventBus.player_energy_changed.emit(owner.current_energy, owner.max_energy)

