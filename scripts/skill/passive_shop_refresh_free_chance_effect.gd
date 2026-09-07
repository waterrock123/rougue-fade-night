class_name PassiveShopRefreshFreeChanceEffect
extends PassiveSkillEffect

## 获得技能时一次性增加金币，并在修整期每次商店刷新后按概率增加一次可储存免费刷新。
@export var immediate_gold: int = 3
@export_range(0.0, 1.0, 0.01) var free_refresh_chance: float = 0.5
@export var initial_gold_counter_key: StringName = &"passive_benefit_exchange_initial_gold"

var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.run_stats == null:
		return
	# 此效果由 Run 下的代理管理，避免战斗 Player 重复发放金币或监听商店。
	if context.caster != null:
		return

	var run_stats: RunStats = context.run_stats
	if run_stats.get_persistent_passive_counter(initial_gold_counter_key) <= 0:
		run_stats.set_gold(run_stats.gold + max(immediate_gold, 0))
		run_stats.set_persistent_passive_counter(initial_gold_counter_key, 1)

	var context_key: String = _get_context_key(context)
	active_contexts[context_key] = context
	if not EventBus.shop_refreshed.is_connected(_on_shop_refreshed):
		EventBus.shop_refreshed.connect(_on_shop_refreshed)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.shop_refreshed.is_connected(_on_shop_refreshed):
		EventBus.shop_refreshed.disconnect(_on_shop_refreshed)


func _on_shop_refreshed(shop: Shop) -> void:
	if shop == null or RunRng.randf() > clamp(free_refresh_chance, 0.0, 1.0):
		return

	for value: Variant in active_contexts.values():
		var context: SkillContext = value as SkillContext
		if context == null or context.run_stats == null or context.run_stats.shop != shop:
			continue
		context.run_stats.add_shop_free_refresh_count(1)


func _get_context_key(context: SkillContext) -> String:
	var controller_id: int = 0
	if context.skill_controller != null:
		controller_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(controller_id), str(context.effect_key)]
