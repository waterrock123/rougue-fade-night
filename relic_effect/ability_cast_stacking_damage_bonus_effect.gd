## 按释放技能次数叠加出伤加成。
## 可用于“冰箱：每释放 10 次非基础技能，冰伤 +1，最多 +5”。
class_name AbilityCastStackingDamageBonusEffect
extends RelicEffect

@export var excluded_slot_indices: Array[int] = []
@export var casts_per_stack: int = 1
@export var max_stacks: int = 5
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var flat_bonus_per_stack: float = 1.0

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var ability_controller := owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var key := str(effect_key)
	var callback := Callable(self, "_on_ability_triggered").bind(owner, key)
	ability_controller.ability_triggered.connect(callback)
	active_entries[key] = {
		"owner": owner,
		"controller": ability_controller,
		"callback": callback,
		"cast_count": 0,
		"stacks": 0,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_entries.has(key):
		return

	var entry := active_entries[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var controller := entry.get("controller") as AbilityController
	var callback := entry.get("callback") as Callable
	if controller != null and is_instance_valid(controller) and controller.ability_triggered.is_connected(callback):
		controller.ability_triggered.disconnect(callback)
	if owner != null and is_instance_valid(owner) and owner.stats_controller != null:
		owner.stats_controller.clear_outgoing_damage_bonus_modifier(key)

	active_entries.erase(key)


func _on_ability_triggered(ability: Ability, caster: Entity, owner: Entity, effect_key: String) -> void:
	if caster != owner or ability == null:
		return
	if excluded_slot_indices.has(ability.runtime_slot_index):
		return

	var entry := active_entries[effect_key] as Dictionary
	entry["cast_count"] = int(entry.get("cast_count", 0)) + 1
	if int(entry["cast_count"]) < max(casts_per_stack, 1):
		active_entries[effect_key] = entry
		return

	entry["cast_count"] = 0
	entry["stacks"] = min(int(entry.get("stacks", 0)) + 1, max(max_stacks, 1))
	active_entries[effect_key] = entry
	_apply_damage_bonus(owner, effect_key, int(entry["stacks"]))


func _apply_damage_bonus(owner: Entity, effect_key: String, stacks: int) -> void:
	if owner == null or owner.stats_controller == null:
		return

	owner.stats_controller.set_outgoing_damage_bonus_modifier(effect_key, {
		"required_tags": required_tags.duplicate(),
		"required_damage_types": required_damage_types.duplicate(),
		"flat_bonus": flat_bonus_per_stack * stacks,
	})


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
