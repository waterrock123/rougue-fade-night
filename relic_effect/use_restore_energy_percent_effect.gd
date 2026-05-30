## 消耗品使用时按最大能量百分比恢复能量的通用效果。
## 适合奶酪、魔力药剂等“回蓝”类消耗品复用。
class_name UseRestoreEnergyPercentEffect
extends RelicEffect

## 恢复最大能量的比例，0.5 表示恢复 50% 最大能量。
@export_range(0.0, 1.0, 0.01) var restore_percent: float = 0.5


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if restore_percent <= 0.0:
		return

	var owner := relic_context.owner as Entity
	var restore_amount := owner.max_energy * restore_percent
	owner.current_energy = min(owner.current_energy + restore_amount, owner.max_energy)

	if owner.stats_controller != null:
		owner.stats_controller.current_energy = owner.current_energy
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_energy_changed.emit(owner.current_energy, owner.max_energy)
