## 进入修整期时，永久扣除一级属性并按比例流失当前生命。
## 只允许 PlayerBuildProxy 注册，避免战斗 Player 和常驻数据重复结算。
class_name RestPeriodPermanentStatsHealthCostEffect
extends RelicEffect

@export_range(0, 99, 1) var primary_stat_loss: int = 1
@export_range(0.0, 1.0, 0.01) var current_health_loss_rate: float = 0.5
@export var minimum_primary_stat: int = 0

var active_contexts: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not (context.owner is PlayerBuildProxy):
		return
	active_contexts[str(effect_key)] = context
	if not EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.connect(_on_rest_period_started)


func on_deactivate(_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.disconnect(_on_rest_period_started)


func _on_rest_period_started() -> void:
	for context_value: Variant in active_contexts.values():
		_apply_cost(context_value as RelicContext)


func _apply_cost(context: RelicContext) -> void:
	if context == null or not (context.owner is PlayerBuildProxy):
		return
	var proxy: PlayerBuildProxy = context.owner as PlayerBuildProxy
	var player_build: PlayerBuild = proxy.player_build
	if player_build == null or player_build.player_stats == null:
		return
	for stat_name: StringName in StatsController.PRIMARY_STATS:
		var old_value: int = int(player_build.player_stats.get(stat_name))
		player_build.player_stats.set(stat_name, max(old_value - primary_stat_loss, minimum_primary_stat))
	# 先重算上限，再扣除当前生命，保证两部分代价都会同步到 PlayerBuild。
	proxy.stats_controller.bind_player_build(player_build)
	proxy.stats_controller.current_health *= 1.0 - clamp(current_health_loss_rate, 0.0, 1.0)
	proxy.stats_controller.sync_runtime_resources()
	EventBus.player_health_changed.emit(proxy.stats_controller.current_health, proxy.stats_controller.get_stat(&"max_health"))
