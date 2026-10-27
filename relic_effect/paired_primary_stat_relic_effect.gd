## 按两项一级属性的当前值计算装备加成，属性变化时自动重算。
## 基础模式按两项属性各满足的整组数提高资源上限；另一模式将较低的其他一级属性补到两项中较高的一项。
class_name PairedPrimaryStatRelicEffect
extends RelicEffect

enum BonusMode { RESOURCE_PER_PAIR, RAISE_OTHER_PRIMARY_STATS }

@export var first_stat: StringName = &"charm"
@export var second_stat: StringName = &"luck"
@export var bonus_mode: BonusMode = BonusMode.RESOURCE_PER_PAIR
@export_range(1, 99, 1) var points_per_pair: int = 2
@export var health_per_pair: float = 5.0
@export var energy_per_pair: float = 5.0

var active_contexts: Dictionary = {}
var refreshing: bool = false


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or context.owner == null:
		return
	var context_key: String = _make_context_key(context.owner, effect_key)
	active_contexts[context_key] = {"context": context, "effect_key": str(effect_key), "applied": {}}
	if not EventBus.attribute_update.is_connected(_on_attribute_update):
		EventBus.attribute_update.connect(_on_attribute_update)
	_refresh_context(context_key)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or context.owner == null:
		return
	active_contexts.erase(_make_context_key(context.owner, effect_key))
	if active_contexts.is_empty() and EventBus.attribute_update.is_connected(_on_attribute_update):
		EventBus.attribute_update.disconnect(_on_attribute_update)
	var controller: StatsController = _get_stats_controller(context)
	if controller != null:
		controller.clear_effect_modifiers(effect_key)


func _on_attribute_update() -> void:
	if refreshing:
		return
	refreshing = true
	for context_key_value: Variant in active_contexts.keys().duplicate():
		_refresh_context(String(context_key_value))
	refreshing = false


func _refresh_context(context_key: String) -> void:
	var record: Dictionary = active_contexts.get(context_key, {}) as Dictionary
	var context: RelicContext = record.get("context") as RelicContext
	if context == null or context.owner == null or not is_instance_valid(context.owner):
		return
	var controller: StatsController = _get_stats_controller(context)
	if controller == null:
		return
	var previous: Dictionary = record.get("applied", {}) as Dictionary
	var desired: Dictionary = _get_desired_bonus(controller, previous)
	if desired == previous:
		return
	record["applied"] = desired
	active_contexts[context_key] = record
	var modifiers: Array[Modifier] = []
	var effect_key: String = String(record.get("effect_key", ""))
	for stat_name_value: Variant in desired.keys():
		modifiers.append(Modifier.create_flat(StringName(stat_name_value), float(desired[stat_name_value]), effect_key))
	controller.set_effect_modifiers(effect_key, modifiers)


func _get_desired_bonus(controller: StatsController, previous: Dictionary) -> Dictionary:
	var first_value: float = controller.get_stat(first_stat)
	var second_value: float = controller.get_stat(second_stat)
	var desired: Dictionary = {}
	if bonus_mode == BonusMode.RESOURCE_PER_PAIR:
		var pairs: int = maxi(int(floor(minf(first_value, second_value) / float(points_per_pair))), 0)
		desired[&"max_health"] = float(pairs) * health_per_pair
		desired[&"max_energy"] = float(pairs) * energy_per_pair
	else:
		var target_value: float = maxf(first_value, second_value)
		for stat_name: StringName in StatsController.PRIMARY_STATS:
			if stat_name == first_stat or stat_name == second_stat:
				continue
			var natural_value: float = controller.get_stat(stat_name) - float(previous.get(stat_name, 0.0))
			desired[stat_name] = maxf(target_value - natural_value, 0.0)
	return desired


func _get_stats_controller(context: RelicContext) -> StatsController:
	return context.relic_controller.get_stats_controller() if context.relic_controller != null else null


func _make_context_key(owner: Node, effect_key) -> String:
	return "%d:%s" % [owner.get_instance_id(), str(effect_key)]
