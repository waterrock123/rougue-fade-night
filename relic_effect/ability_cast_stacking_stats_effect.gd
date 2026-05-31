## 释放技能时叠加临时属性的通用遗物效果。
## 可配置排除基础攻击、每 N 次触发、最大层数、持续时间，复用于法师帽/充能手甲等装备。
class_name AbilityCastStackingStatsEffect
extends RelicEffect


@export var add_stats_per_stack: Dictionary = {}
@export var add_derived_stats_per_stack: Dictionary = {}
@export var target_slot_indices: Array[int] = []
@export var excluded_slot_indices: Array[int] = []
@export var casts_per_stack: int = 1
@export var max_stacks: int = 99
## 小于 0 表示持续到战斗结束；大于 0 表示每次触发后重新倒计时，时间到清空。
@export var duration: float = -1.0
## 勾选后，遗物已经处于升级态时不再注册这条叠层效果。
## 适合“未升级是限时叠层，升级后改成另一条永久叠层”的装备。
@export var ignore_when_relic_levelup: bool = false

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if ignore_when_relic_levelup and relic_context != null and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var ability_controller := owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var key := str(effect_key)
	if active_entries.has(key):
		return

	var callback := Callable(self, "_on_ability_triggered").bind(owner, key)
	ability_controller.ability_triggered.connect(callback)
	active_entries[key] = {
		"owner": owner,
		"controller": ability_controller,
		"callback": callback,
		"stacks": 0,
		"cast_count": 0,
		"revision": 0,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	_clear_entry(str(effect_key))


func _on_ability_triggered(ability: Ability, caster: Entity, owner: Entity, effect_key: String) -> void:
	if caster != owner or ability == null:
		return
	if not _ability_matches(ability):
		return
	if not active_entries.has(effect_key):
		return

	var entry := active_entries[effect_key] as Dictionary
	entry["cast_count"] = int(entry.get("cast_count", 0)) + 1
	if int(entry["cast_count"]) < max(casts_per_stack, 1):
		active_entries[effect_key] = entry
		return

	entry["cast_count"] = 0
	entry["stacks"] = min(int(entry.get("stacks", 0)) + 1, max(max_stacks, 1))
	entry["revision"] = int(entry.get("revision", 0)) + 1
	active_entries[effect_key] = entry
	_apply_modifiers(owner, effect_key, int(entry["stacks"]))

	if duration > 0.0:
		_clear_after_duration(effect_key, int(entry["revision"]), duration)


func _apply_modifiers(owner: Entity, effect_key: String, stacks: int) -> void:
	if owner == null or owner.stats_controller == null:
		return

	var modifiers: Array[Modifier] = []
	for stat_name in add_stats_per_stack.keys():
		modifiers.append(Modifier.create_flat(StringName(stat_name), float(add_stats_per_stack[stat_name]) * stacks, effect_key))
	for stat_name in add_derived_stats_per_stack.keys():
		modifiers.append(Modifier.create_flat(StringName(stat_name), float(add_derived_stats_per_stack[stat_name]) * stacks, effect_key))

	owner.stats_controller.set_effect_modifiers(effect_key, modifiers)


func _clear_after_duration(effect_key: String, revision: int, delay: float) -> void:
	if not active_entries.has(effect_key):
		return

	var entry := active_entries[effect_key] as Dictionary
	var owner := entry.get("owner") as Entity
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return

	await owner.get_tree().create_timer(delay).timeout
	if not active_entries.has(effect_key):
		return

	var latest := active_entries[effect_key] as Dictionary
	if int(latest.get("revision", -1)) != revision:
		return

	latest["stacks"] = 0
	latest["cast_count"] = 0
	active_entries[effect_key] = latest
	if owner != null and is_instance_valid(owner) and owner.stats_controller != null:
		owner.stats_controller.clear_effect_modifiers(effect_key)


func _clear_entry(effect_key: String) -> void:
	if not active_entries.has(effect_key):
		return

	var entry := active_entries[effect_key] as Dictionary
	var owner := entry.get("owner") as Entity
	var controller := entry.get("controller") as AbilityController
	var callback := entry.get("callback") as Callable
	if controller != null and is_instance_valid(controller) and controller.ability_triggered.is_connected(callback):
		controller.ability_triggered.disconnect(callback)
	if owner != null and is_instance_valid(owner) and owner.stats_controller != null:
		owner.stats_controller.clear_effect_modifiers(effect_key)

	active_entries.erase(effect_key)


func _ability_matches(ability: Ability) -> bool:
	if not target_slot_indices.is_empty() and not target_slot_indices.has(ability.runtime_slot_index):
		return false
	if excluded_slot_indices.has(ability.runtime_slot_index):
		return false
	return true


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
