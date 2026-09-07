class_name PassiveKillCountGrantShopRelicEffect
extends PassiveSkillEffect

## 跨战斗累计击杀敌人，达到阈值后奖励一件不高于当前商店等级的装备。
## 奖励失败时会保留计数，等背包出现空间后继续尝试，不会无声丢失奖励。
@export var kill_threshold: int = 30
@export var counter_key: StringName = &"scount_treasure_hunter_kills"

var active_contexts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.caster == null or context.run_stats == null:
		return
	if not context.caster.is_in_group("player"):
		return

	var context_key: String = _get_context_key(context)
	active_contexts[context_key] = context
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	active_contexts.erase(_get_context_key(context))
	if active_contexts.is_empty() and EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _on_enemy_killed(_enemy: Entity, killer: Entity) -> void:
	if killer == null:
		return

	var contexts: Array[SkillContext] = []
	for value: Variant in active_contexts.values():
		var context: SkillContext = value as SkillContext
		if context != null and context.caster == killer:
			contexts.append(context)

	for context: SkillContext in contexts:
		_process_kill_for_context(context)


func _process_kill_for_context(context: SkillContext) -> void:
	var threshold: int = max(kill_threshold, 1)
	var current_count: int = context.run_stats.add_persistent_passive_counter(counter_key)

	while current_count >= threshold:
		if not _grant_random_shop_relic(context):
			break
		current_count -= threshold

	context.run_stats.set_persistent_passive_counter(counter_key, current_count)


func _grant_random_shop_relic(context: SkillContext) -> bool:
	if context == null or context.run_stats == null or context.player_build == null:
		return false

	var shop: Shop = context.run_stats.shop
	if shop == null or shop.shopkeeper == null:
		return false

	var candidates: Array[Relic] = shop.shopkeeper.get_available_relics(shop.level)
	if candidates.is_empty():
		return false

	var picked_value: Variant = RunRng.pick(candidates)
	var template: Relic = picked_value as Relic
	if template == null:
		return false

	var reward: Relic = template.duplicate(true) as Relic
	if reward == null or not context.player_build.add_relic(reward):
		return false

	var owner: Entity = context.caster
	var relic_controller: RelicController = owner.get_node_or_null("RelicController") as RelicController
	reward.gain_relic(owner, relic_controller, "treasure_hunter_%s" % str(reward.get_instance_id()))
	return true


func _get_context_key(context: SkillContext) -> String:
	var controller_id: int = 0
	if context.skill_controller != null:
		controller_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(controller_id), str(context.effect_key)]
