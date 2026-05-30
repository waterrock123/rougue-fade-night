## 装备生效期间，使用消耗品时获得战斗内属性提升的通用效果。
## 适合“小罐盐”这类围绕消耗品触发的运营装备。
class_name ConsumableUseStatsEffect
extends RelicEffect

## 每次使用任意消耗品时增加的一级属性。
@export var base_add_stats: Dictionary = {}
## 若使用的消耗品拥有这个 tag，则额外增加 bonus_add_stats。
@export var bonus_tag: RelicTag
## 命中 bonus_tag 后额外增加的一级属性。
@export var bonus_add_stats: Dictionary = {}

var active_contexts: Dictionary = {}
var accumulated_stats: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return

	var key := str(effect_key)
	active_contexts[key] = relic_context
	accumulated_stats[key] = accumulated_stats.get(key, {})

	if not EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.connect(_on_consumable_used)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	_clear_modifiers(relic_context, key)
	active_contexts.erase(key)
	accumulated_stats.erase(key)

	if active_contexts.is_empty() and EventBus.consumable_used.is_connected(_on_consumable_used):
		EventBus.consumable_used.disconnect(_on_consumable_used)


func _on_consumable_used(relic: Relic, user: Entity) -> void:
	for key in active_contexts.keys():
		var relic_context := active_contexts[key] as RelicContext
		if relic_context == null or relic_context.owner != user:
			continue

		_add_trigger_stats(str(key), relic_context, relic)


func _add_trigger_stats(key: String, relic_context: RelicContext, used_relic: Relic) -> void:
	var totals := accumulated_stats.get(key, {}) as Dictionary
	_add_stats_to_totals(totals, base_add_stats)
	if _relic_has_tag(used_relic, bonus_tag):
		_add_stats_to_totals(totals, bonus_add_stats)

	accumulated_stats[key] = totals
	_apply_totals_as_modifiers(relic_context, key, totals)


func _add_stats_to_totals(totals: Dictionary, stats: Dictionary) -> void:
	for stat_name in stats.keys():
		totals[stat_name] = float(totals.get(stat_name, 0.0)) + float(stats[stat_name])


func _apply_totals_as_modifiers(relic_context: RelicContext, key: String, totals: Dictionary) -> void:
	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	var modifiers: Array[Modifier] = []
	for stat_name in totals.keys():
		var amount := float(totals[stat_name])
		if amount != 0.0:
			modifiers.append(Modifier.create_flat(StringName(stat_name), amount, key))

	stats_controller.set_effect_modifiers(key, modifiers)


func _clear_modifiers(relic_context: RelicContext, key: String) -> void:
	var stats_controller := _get_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.clear_effect_modifiers(key)


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag:
			return true
		if not relic_tag.tag_name.is_empty() and relic_tag.tag_name == target_tag.tag_name:
			return true
	return false


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null
