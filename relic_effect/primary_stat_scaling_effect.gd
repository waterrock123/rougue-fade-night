## 按当前一级属性的完整分组数，动态提供另一项属性。
## 例如每 5 点敏捷提供 1 点魅力；低于一组不加成，卸下时撤销。
class_name PrimaryStatScalingEffect
extends RelicEffect

@export var source_stat: StringName = &"dexterity"
@export_range(1.0, 100.0, 1.0) var points_per_group: float = 5.0
@export var target_stat: StringName = &"charm"
@export var value_per_group: float = 1.0

var contexts: Dictionary = {}
var refreshing: bool = false


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or source_stat == target_stat:
		return
	var key: String = "%d:%s" % [context.owner.get_instance_id(), str(effect_key)]
	if contexts.has(key):
		return
	contexts[key] = {"context": context, "effect_key": str(effect_key), "amount": NAN}
	if not EventBus.attribute_update.is_connected(_refresh):
		EventBus.attribute_update.connect(_refresh)
	_refresh()


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var key: String = "%d:%s" % [context.owner.get_instance_id(), str(effect_key)]
	contexts.erase(key)
	if contexts.is_empty() and EventBus.attribute_update.is_connected(_refresh):
		EventBus.attribute_update.disconnect(_refresh)
	var controller: StatsController = _get_controller(context)
	if controller != null:
		controller.clear_effect_modifiers(str(effect_key))


func _refresh() -> void:
	# set_effect_modifiers 会再次发送 attribute_update，防止递归与重复重算。
	if refreshing:
		return
	refreshing = true
	for key: String in contexts.keys():
		var record: Dictionary = contexts[key]
		var context: RelicContext = record["context"]
		var controller: StatsController = _get_controller(context)
		if controller == null:
			continue
		var amount: float = calculate_bonus(controller.get_stat(source_stat))
		if amount == float(record["amount"]):
			continue
		record["amount"] = amount
		var modifiers: Array[Modifier] = [Modifier.create_flat(target_stat, amount, record["effect_key"])]
		controller.set_effect_modifiers(record["effect_key"], modifiers)
	refreshing = false


func calculate_bonus(source_value: float) -> float:
	return maxf(floorf(source_value / maxf(points_per_group, 1.0)), 0.0) * value_per_group


func _get_controller(context: RelicContext) -> StatsController:
	if context == null or not is_instance_valid(context.owner):
		return null
	if is_instance_valid(context.relic_controller):
		return context.relic_controller.get_stats_controller()
	if context.owner is Entity:
		return (context.owner as Entity).stats_controller
	return context.owner.get_node_or_null("StatsController") as StatsController
