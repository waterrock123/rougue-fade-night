class_name InventoryRelicCountStatEffect
extends RelicEffect

## 按背包中某种装备的数量动态提供属性，例如每件鸡蛋使全属性 +1。
@export var target_relic_id: String = ""
@export var stat_bonuses_per_relic: Dictionary = {}
@export var include_locked_slots: bool = true

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or target_relic_id.is_empty():
		return
	active_contexts[str(effect_key)] = relic_context
	if not EventBus.inventory_update.is_connected(_on_inventory_changed):
		EventBus.inventory_update.connect(_on_inventory_changed)
	_refresh_context(relic_context, effect_key)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	_clear_context(relic_context, effect_key)
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.inventory_update.is_connected(_on_inventory_changed):
		EventBus.inventory_update.disconnect(_on_inventory_changed)


func _on_inventory_changed() -> void:
	for key_variant in active_contexts.keys():
		var key: String = str(key_variant)
		_refresh_context(active_contexts[key] as RelicContext, key)


func _refresh_context(relic_context: RelicContext, effect_key: Variant) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	var count: int = _count_inventory_relics(relic_context)
	var modifiers: Array[Modifier] = []
	for stat_name_variant in stat_bonuses_per_relic.keys():
		var amount: float = float(stat_bonuses_per_relic[stat_name_variant]) * float(count)
		if amount != 0.0:
			modifiers.append(Modifier.create_flat(StringName(str(stat_name_variant)), amount, effect_key))
	stats_controller.set_effect_modifiers(effect_key, modifiers)


func _clear_context(relic_context: RelicContext, effect_key: Variant) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.clear_effect_modifiers(effect_key)


func _count_inventory_relics(relic_context: RelicContext) -> int:
	var inventory: Inventory = _get_inventory(relic_context)
	if inventory == null:
		return 0

	var count: int = 0
	for slot: Slot in inventory.slots:
		if slot == null or slot.item == null or slot.item.id != target_relic_id:
			continue
		if not include_locked_slots and slot.is_locked:
			continue
		count += 1
	return count


func _get_inventory(relic_context: RelicContext) -> Inventory:
	if relic_context == null:
		return null
	if relic_context.owner is Player:
		return (relic_context.owner as Player).player_inventory
	if relic_context.owner is PlayerBuildProxy:
		var proxy: PlayerBuildProxy = relic_context.owner as PlayerBuildProxy
		return proxy.player_build.player_inventory if proxy.player_build != null else null
	if relic_context.owner is Entity and (relic_context.owner as Entity).stats_controller != null:
		var build: PlayerBuild = (relic_context.owner as Entity).stats_controller.player_build
		return build.player_inventory if build != null else null
	return null


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	return relic_context.owner.get_node_or_null("StatsController") as StatsController

