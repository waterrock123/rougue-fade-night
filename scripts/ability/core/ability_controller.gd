class_name AbilityController
extends Node

signal ability_triggered(ability: Ability, caster: Entity)

var abilities: Array[Ability] = []
var cooldowns: Dictionary = {}
var cooldown_modifiers: Dictionary = {}
var runtime_abilities: Array[Ability] = []
var runtime_ability_sources: Dictionary = {}
var previewing_ability: Ability

var entity: Entity


func _ready():
	entity = get_parent() as Entity
	_rebuild_ability_cache()


func trigger_ability_by_idx(idx: int):
	if idx < 0 or idx >= abilities.size():
		return

	var ability := abilities[idx]
	trigger_ability(ability)


func begin_ability_preview_by_idx(idx: int) -> void:
	if idx < 0 or idx >= abilities.size():
		return

	begin_ability_preview(abilities[idx])


func release_ability_preview_by_idx(idx: int) -> void:
	if idx < 0 or idx >= abilities.size():
		return

	release_ability_preview(abilities[idx])


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
	if entity.has_method("can_act") and not entity.can_act():
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
	if entity.is_dead:
		return
	if entity.has_method("can_act") and not entity.can_act():
		return
	if cooldowns.get(ability, 0.0) > 0.0:
		return
	if entity.current_energy < ability.energy_cost:
		return

	entity.spend_energy(ability.energy_cost)
	ability.activate(entity)
	ability_triggered.emit(ability, entity)
	cooldowns[ability] = _get_modified_cooldown(ability)


# 注册一个由状态/被动提供的冷却修正。
func set_cooldown_modifier(source_key: Variant, modifier_data: Dictionary) -> void:
	if source_key == null:
		return
	cooldown_modifiers[str(source_key)] = modifier_data.duplicate(true)


# 移除指定来源的冷却修正。
func clear_cooldown_modifier(source_key: Variant) -> void:
	if source_key == null:
		return
	cooldown_modifiers.erase(str(source_key))


func begin_ability_preview(ability: Ability) -> void:
	if ability == null or entity == null:
		return
	if entity.is_dead:
		return
	if entity.has_method("can_act") and not entity.can_act():
		return
	# 没有预览组件的旧技能仍然保持原逻辑：按下按键就直接释放。
	if not ability.has_cast_preview():
		trigger_ability(ability)
		return
	if not _can_be_cast(ability):
		return

	# 同一时间只允许预览一个技能，避免多个指示器叠在一起。
	cancel_ability_preview()
	previewing_ability = ability
	ability.begin_cast_preview(entity)


func release_ability_preview(ability: Ability) -> void:
	if ability == null or ability != previewing_ability:
		return

	# 松开按键时关闭指示器，再走正式释放流程，冷却和能量仍由 trigger_ability 统一校验。
	ability.end_cast_preview()
	previewing_ability = null
	trigger_ability(ability)


func cancel_ability_preview() -> void:
	if previewing_ability != null:
		previewing_ability.end_cast_preview()
		previewing_ability = null


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
	if previewing_ability == ability:
		cancel_ability_preview()

	if ability.get_parent() == self:
		remove_child(ability)
	ability.queue_free()


func _get_modified_cooldown(ability: Ability) -> float:
	var cooldown := ability.cooldown
	if cooldown <= 0.0:
		return 0.0

	var stat_cooldown_reduction := 0.0
	if entity != null and entity.stats_controller != null:
		stat_cooldown_reduction = clamp(entity.stats_controller.get_stat("cooldown_reduction"), 0.0, 0.9)
	cooldown *= 1.0 - stat_cooldown_reduction

	var slot_index := abilities.find(ability)
	for modifier_data in cooldown_modifiers.values():
		if not _cooldown_modifier_matches(ability, slot_index, modifier_data):
			continue

		cooldown *= float(modifier_data.get("cooldown_multiplier", 1.0))
		cooldown -= float(modifier_data.get("flat_reduction", 0.0))

	return max(cooldown, 0.05)


func _cooldown_modifier_matches(ability: Ability, slot_index: int, modifier_data: Dictionary) -> bool:
	var target_ids: Array = modifier_data.get("target_ability_ids", [])
	if not target_ids.is_empty():
		return target_ids.has(ability.id)

	var target_slots: Array = modifier_data.get("target_slot_indices", [])
	if not target_slots.is_empty():
		return target_slots.has(slot_index)

	return true
