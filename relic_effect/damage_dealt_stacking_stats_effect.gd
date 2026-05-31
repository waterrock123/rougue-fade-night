## 造成符合条件的伤害后叠加临时属性。
## 用于“释放/命中投射物后提高暴击率”等战斗内成长。
class_name DamageDealtStackingStatsEffect
extends RelicEffect

@export var add_derived_stats_per_stack: Dictionary = {}
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var max_stacks: int = 999

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var key := str(effect_key)
	if active_entries.has(key):
		return

	var callback := Callable(self, "_on_damage_dealt").bind(owner, key)
	owner.damage_dealt.connect(callback)
	active_entries[key] = {
		"owner": owner,
		"callback": callback,
		"stacks": 0,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_entries.has(key):
		return

	var entry := active_entries[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callback := entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.disconnect(callback)
	if owner != null and is_instance_valid(owner) and owner.stats_controller != null:
		owner.stats_controller.clear_effect_modifiers(key)

	active_entries.erase(key)


func _on_damage_dealt(damage_data: DamageData, owner: Entity, effect_key: String) -> void:
	if owner == null or not is_instance_valid(owner) or owner.stats_controller == null:
		return
	if damage_data == null or damage_data.final_damage <= 0.0:
		return
	if not _damage_matches(damage_data):
		return

	var entry := active_entries[effect_key] as Dictionary
	entry["stacks"] = min(int(entry.get("stacks", 0)) + 1, max(max_stacks, 1))
	active_entries[effect_key] = entry
	_apply_modifiers(owner, effect_key, int(entry["stacks"]))


func _apply_modifiers(owner: Entity, effect_key: String, stacks: int) -> void:
	var modifiers: Array[Modifier] = []
	for stat_name in add_derived_stats_per_stack.keys():
		modifiers.append(Modifier.create_flat(StringName(stat_name), float(add_derived_stats_per_stack[stat_name]) * stacks, effect_key))

	owner.stats_controller.set_effect_modifiers(effect_key, modifiers)


func _damage_matches(damage_data: DamageData) -> bool:
	for tag in required_tags:
		if not damage_data.tags.has(tag):
			return false
	for damage_type in required_damage_types:
		if not damage_data.damage_types.has(damage_type):
			return false
	return true


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
