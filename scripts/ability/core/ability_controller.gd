class_name AbilityController
extends Node

var abilities: Array[Ability] = []
var cooldowns: Dictionary = {}
var runtime_abilities: Array[Ability] = []
var runtime_ability_sources: Dictionary = {}

var entity: Entity


func _ready():
	entity = get_parent() as Entity
	_rebuild_ability_cache()


func trigger_ability_by_idx(idx: int):
	if idx < 0 or idx >= abilities.size():
		return

	var ability := abilities[idx]
	trigger_ability(ability)


func _process(delta: float) -> void:
	for ability in abilities:
		if cooldowns.get(ability, 0.0) > 0.0:
			var cooldown = max(0.0, cooldowns[ability] - delta)
			cooldowns[ability] = cooldown
			ability.current_cooldown = cooldown

		ability.can_be_casted = _can_be_cast(ability)


func _can_be_cast(ability: Ability):
	if entity == null:
		return false

	var cd = cooldowns.get(ability, 0.0)
	return cd == 0 and ability.energy_cost <= entity.current_energy


# 运行时注册一个主动技能场景，并返回实例化后的 Ability。
func register_runtime_ability(ability_scene: PackedScene, source_id) -> Ability:
	if ability_scene == null:
		return null

	if runtime_ability_sources.has(source_id):
		var old_ability := runtime_ability_sources[source_id] as Ability
		_unregister_runtime_ability(old_ability)

	var ability_instance := ability_scene.instantiate() as Ability
	if ability_instance == null:
		return null

	add_child(ability_instance)
	runtime_abilities.append(ability_instance)
	runtime_ability_sources[source_id] = ability_instance
	abilities.append(ability_instance)
	return ability_instance


# 清空所有运行时动态添加的主动技能。
func clear_runtime_abilities():
	for ability in runtime_abilities.duplicate():
		_unregister_runtime_ability(ability)

	runtime_abilities.clear()
	runtime_ability_sources.clear()


func trigger_ability(ability: Ability):
	if ability == null:
		return
	if entity == null:
		return
	if cooldowns.get(ability, 0.0) > 0.0:
		return
	if entity.current_energy < ability.energy_cost:
		return

	entity.spend_energy(ability.energy_cost)
	ability.activate(entity)
	cooldowns[ability] = ability.cooldown


func _rebuild_ability_cache() -> void:
	abilities.clear()
	for child in get_children():
		if child is Ability:
			abilities.push_back(child)


func _unregister_runtime_ability(ability: Ability) -> void:
	if ability == null:
		return

	abilities.erase(ability)
	runtime_abilities.erase(ability)
	cooldowns.erase(ability)

	if ability.get_parent() == self:
		remove_child(ability)
	ability.queue_free()
