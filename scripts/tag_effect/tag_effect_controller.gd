class_name TagEffectController
extends Node

signal tag_effects_changed(snapshots: Array)

## 局外选择系统还没做时，先用这里作为默认可选配置来源。
@export var default_tag_effects: Array[TagEffect] = []

var run_stats: RunStats
var effect_owner: Node
var stats_controller: StatsController
var active_effects: Dictionary = {}
var current_snapshots: Array[Dictionary] = []


func _exit_tree() -> void:
	_disconnect_signals()
	_deactivate_all()


func bind_context(new_run_stats: RunStats, new_owner: Node, new_default_tag_effects: Array[TagEffect] = []) -> void:
	run_stats = new_run_stats
	effect_owner = new_owner
	default_tag_effects = new_default_tag_effects.duplicate()
	stats_controller = _resolve_stats_controller(effect_owner)

	_connect_signals()
	refresh()


func get_snapshots() -> Array[Dictionary]:
	return current_snapshots.duplicate(true)


func refresh() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	var selected_effects := _get_selected_effects()
	var next_active_keys: Array[String] = []
	current_snapshots.clear()

	for effect in selected_effects:
		if effect == null:
			continue

		var counted_relics := _collect_counted_relics(effect)
		var effect_key := _build_effect_key(effect)
		var context := TagEffectContext.new(
			run_stats,
			effect_owner,
			stats_controller,
			self,
			effect,
			effect_key,
			counted_relics.size(),
			counted_relics
		)
		var can_activate := effect.can_activate(context)
		var completed_once := effect.is_once and context.is_once_completed()
		var owned_tag_relics := _collect_owned_relics_for_tag(effect.tag)

		current_snapshots.append({
			"effect": effect,
			"tag": effect.tag,
			"name": effect.get_display_name(),
			"desc": effect.desc,
			"count": counted_relics.size(),
			"owned_count": owned_tag_relics.size(),
			"has_owned_tag": not owned_tag_relics.is_empty(),
			"required_count": effect.required_count,
			"is_active": can_activate and not effect.is_once,
			"is_completed": completed_once,
		})

		if effect.is_once:
			if can_activate:
				effect.on_activate(context)
			continue

		if can_activate:
			next_active_keys.append(effect_key)
			if not active_effects.has(effect_key):
				effect.on_activate(context)
				active_effects[effect_key] = {
					"effect": effect,
					"context": context,
				}
		elif active_effects.has(effect_key):
			_deactivate_effect(effect_key)

	for effect_key in active_effects.keys().duplicate():
		if not next_active_keys.has(effect_key):
			_deactivate_effect(effect_key)

	tag_effects_changed.emit(get_snapshots())


func _get_selected_effects() -> Array[TagEffect]:
	var source_effects: Array[TagEffect]
	if run_stats != null and not run_stats.selected_tag_effects.is_empty():
		source_effects = run_stats.selected_tag_effects
	else:
		source_effects = default_tag_effects

	# 同一个 tag 本局只允许一个效果生效；如果局外配置误放了多个，就按数组顺序取第一个。
	var result: Array[TagEffect] = []
	var used_tag_keys: Array[String] = []
	for effect in source_effects:
		if effect == null:
			continue
		var tag_key := effect.get_tag_key()
		if tag_key.is_empty() or used_tag_keys.has(tag_key):
			continue
		used_tag_keys.append(tag_key)
		result.append(effect)
	return result


func _collect_counted_relics(effect: TagEffect) -> Array[Relic]:
	var result: Array[Relic] = []
	var seen_ids: Array[String] = []
	var player_build := run_stats.player_build

	if effect.count_source == TagEffect.CountSource.EQUIPMENT_ONLY:
		_collect_from_slots(player_build.player_equipment.equip_slots if player_build.player_equipment != null else [], effect, seen_ids, result)
	else:
		_collect_from_slots(player_build.player_equipment.equip_slots if player_build.player_equipment != null else [], effect, seen_ids, result)
		_collect_from_slots(player_build.player_inventory.slots if player_build.player_inventory != null else [], effect, seen_ids, result)

	return result


# UI 展示用：只要背包或装备栏拥有该 tag 的装备，就说明这个 tag 对玩家当前构筑有关。
func _collect_owned_relics_for_tag(tag: RelicTag) -> Array[Relic]:
	var result: Array[Relic] = []
	var seen_ids: Array[String] = []
	if run_stats == null or run_stats.player_build == null:
		return result

	var player_build := run_stats.player_build
	_collect_owned_tag_from_slots(player_build.player_equipment.equip_slots if player_build.player_equipment != null else [], tag, seen_ids, result)
	_collect_owned_tag_from_slots(player_build.player_inventory.slots if player_build.player_inventory != null else [], tag, seen_ids, result)
	return result


func _collect_from_slots(slots: Array, effect: TagEffect, seen_ids: Array[String], result: Array[Relic]) -> void:
	for slot in slots:
		if slot == null or slot.item == null:
			continue

		var relic := slot.item as Relic
		if relic == null or seen_ids.has(relic.id):
			continue
		if _relic_has_tag(relic, effect.tag):
			seen_ids.append(relic.id)
			result.append(relic)


func _collect_owned_tag_from_slots(slots: Array, tag: RelicTag, seen_ids: Array[String], result: Array[Relic]) -> void:
	for slot in slots:
		if slot == null or slot.item == null:
			continue

		var relic := slot.item as Relic
		if relic == null or seen_ids.has(relic.id):
			continue
		if _relic_has_tag(relic, tag):
			seen_ids.append(relic.id)
			result.append(relic)


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


func _deactivate_effect(effect_key: String) -> void:
	if not active_effects.has(effect_key):
		return

	var entry := active_effects[effect_key] as Dictionary
	var effect := entry.get("effect") as TagEffect
	var context := entry.get("context") as TagEffectContext
	if effect != null:
		effect.on_deactivate(context)
	active_effects.erase(effect_key)


func _deactivate_all() -> void:
	for effect_key in active_effects.keys().duplicate():
		_deactivate_effect(str(effect_key))


func _build_effect_key(effect: TagEffect) -> String:
	return "tag_effect_%s" % String(effect.id)


func _resolve_stats_controller(target_owner: Node) -> StatsController:
	if target_owner == null:
		return null
	if target_owner.has_method("get_stats_controller"):
		return target_owner.get_stats_controller()
	if target_owner is Entity:
		return (target_owner as Entity).stats_controller
	return target_owner.get_node_or_null("StatsController") as StatsController


func _connect_signals() -> void:
	if not EventBus.inventory_update.is_connected(refresh):
		EventBus.inventory_update.connect(refresh)
	if not EventBus.equipment_update.is_connected(refresh):
		EventBus.equipment_update.connect(refresh)


func _disconnect_signals() -> void:
	if EventBus.inventory_update.is_connected(refresh):
		EventBus.inventory_update.disconnect(refresh)
	if EventBus.equipment_update.is_connected(refresh):
		EventBus.equipment_update.disconnect(refresh)
