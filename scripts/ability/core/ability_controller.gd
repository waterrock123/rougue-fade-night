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

@export_group("替代法力")
## 电力状态 id。释放主动技能时，如果当前法力不足，会把这个状态的层数按 energy_per_power_stack 折算法力。
@export var power_status_id: StringName = &"power"
## 每一层电力可视作多少点法力。实际消耗时按层向上取整，多出的部分不会返还。
@export var energy_per_power_stack: float = 3.0


func _ready():
	entity = get_parent() as Entity
	_rebuild_ability_cache()


func trigger_ability_by_idx(idx: int) -> bool:
	if idx < 0 or idx >= abilities.size():
		return false

	var ability := abilities[idx]
	return trigger_ability(ability)


# AI 使用：从第一个可释放技能开始尝试，适合只有单一攻击方式的小怪。
func trigger_first_available_ability() -> bool:
	for ability in abilities:
		if trigger_ability(ability):
			return true
	return false


# AI 使用：从指定索引开始循环寻找可释放技能，成功后返回下一次应该继续尝试的位置。
func trigger_next_available_ability(start_idx: int = 0) -> int:
	if abilities.is_empty():
		return 0

	var safe_start := wrapi(start_idx, 0, abilities.size())
	for offset in range(abilities.size()):
		var index := (safe_start + offset) % abilities.size()
		if trigger_ability(abilities[index]):
			return (index + 1) % abilities.size()

	return safe_start


# AI 使用：在所有可释放技能里随机挑一个，适合技能顺序不固定的精英怪或 Boss。
func trigger_random_available_ability() -> bool:
	var castable_abilities := get_castable_abilities()
	if castable_abilities.is_empty():
		return false

	return trigger_ability(castable_abilities.pick_random())


## AI 使用：只尝试释放“当前目标距离”满足技能 AI 距离配置，且视线没有被墙挡住的技能。
func trigger_first_available_ability_for_ai(target_distance: float, fallback_cast_range: float, target: Entity = null) -> bool:
	for ability in abilities:
		if _can_ai_cast(ability, target_distance, fallback_cast_range, target) and trigger_ability(ability):
			return true
	return false


## AI 使用：循环寻找当前距离可释放的技能，适合有多技能轮换的敌人/Boss。
func trigger_next_available_ability_for_ai(start_idx: int, target_distance: float, fallback_cast_range: float, target: Entity = null) -> int:
	if abilities.is_empty():
		return -1

	var safe_start := wrapi(start_idx, 0, abilities.size())
	for offset in range(abilities.size()):
		var index := (safe_start + offset) % abilities.size()
		var ability := abilities[index]
		if _can_ai_cast(ability, target_distance, fallback_cast_range, target) and trigger_ability(ability):
			return (index + 1) % abilities.size()

	return -1


## AI 使用：在当前距离可释放的技能里随机挑一个。
func trigger_random_available_ability_for_ai(target_distance: float, fallback_cast_range: float, target: Entity = null) -> bool:
	var castable_abilities := get_ai_castable_abilities(target_distance, fallback_cast_range, target)
	if castable_abilities.is_empty():
		return false

	return trigger_ability(castable_abilities.pick_random())


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


func can_cast_ability(ability: Ability) -> bool:
	return _can_be_cast(ability)


func get_castable_abilities() -> Array[Ability]:
	var result: Array[Ability] = []
	for ability in abilities:
		if _can_be_cast(ability):
			result.append(ability)
	return result


func get_ai_castable_abilities(target_distance: float, fallback_cast_range: float, target: Entity = null) -> Array[Ability]:
	var result: Array[Ability] = []
	for ability in abilities:
		if _can_ai_cast(ability, target_distance, fallback_cast_range, target):
			result.append(ability)
	return result


func _can_be_cast(ability: Ability) -> bool:
	if ability == null:
		return false
	if entity == null:
		return false
	if entity.has_method("can_act") and not entity.can_act():
		return false

	var cd = cooldowns.get(ability, 0.0)
	return cd == 0 and _has_enough_ability_energy(ability.energy_cost) and ability.can_pay_activation_costs(entity)


func _can_ai_cast(ability: Ability, target_distance: float, fallback_cast_range: float, target: Entity = null) -> bool:
	if not _can_be_cast(ability):
		return false
	if not ability.can_ai_cast_at_distance(target_distance, fallback_cast_range):
		return false
	if not _has_ai_line_of_sight(ability, target):
		return false

	return true


func _has_ai_line_of_sight(ability: Ability, target: Entity) -> bool:
	if ability == null:
		return false
	if not ability.ai_requires_line_of_sight:
		return true
	# 辅助技能、召唤技能这类没有明确目标的 AI 行为不做视线拦截。
	if target == null:
		return true
	if not is_instance_valid(target):
		return false
	if entity == null or not is_instance_valid(entity):
		return false
	if not entity.is_inside_tree() or not target.is_inside_tree():
		return false

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		entity.global_position,
		target.global_position,
		ability.ai_line_of_sight_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var collision: Dictionary = entity.get_world_2d().direct_space_state.intersect_ray(query)
	return collision.is_empty()


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


func trigger_ability(ability: Ability) -> bool:
	if ability == null:
		return false
	if entity == null:
		return false
	if entity.is_dead:
		return false
	if entity.has_method("can_act") and not entity.can_act():
		return false
	if cooldowns.get(ability, 0.0) > 0.0:
		return false
	if not _has_enough_ability_energy(ability.energy_cost):
		return false
	if not ability.can_pay_activation_costs(entity):
		_show_ability_block_reason(ability)
		return false
	if not ability.pay_activation_costs(entity):
		_show_ability_block_reason(ability)
		return false

	if not _spend_ability_energy(ability.energy_cost):
		return false

	ability.activate(entity)
	ability_triggered.emit(ability, entity)
	cooldowns[ability] = _get_modified_cooldown(ability)
	return true


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
		_show_ability_block_reason(ability)
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


func _show_ability_block_reason(ability: Ability) -> void:
	if ability == null or entity == null:
		return

	var reason := ability.get_activation_block_reason(entity)
	if reason.is_empty():
		return
	if FloatText != null and FloatText.has_method("show_screen_tip"):
		FloatText.show_screen_tip(reason)


func _has_enough_ability_energy(energy_cost: float) -> bool:
	if entity == null:
		return false
	if energy_cost <= 0.0:
		return true
	if entity.current_energy >= energy_cost:
		return true

	var power_stack_count: int = _get_power_stack_count()
	var virtual_energy: float = float(power_stack_count) * max(energy_per_power_stack, 0.0)
	return entity.current_energy + virtual_energy >= energy_cost


func _spend_ability_energy(energy_cost: float) -> bool:
	if entity == null:
		return false
	if energy_cost <= 0.0:
		return true

	if entity.current_energy >= energy_cost:
		entity.spend_energy(energy_cost)
		return true

	var current_energy: float = max(entity.current_energy, 0.0)
	var missing_energy: float = energy_cost - current_energy
	var power_stacks_needed: int = _get_power_stacks_needed(missing_energy)
	if power_stacks_needed <= 0:
		return false
	if _get_power_stack_count() < power_stacks_needed:
		return false

	# 法力不足时会先消耗当前全部法力，再按层数扣除电力；电力溢出的法力不会返还。
	if current_energy > 0.0:
		entity.spend_energy(current_energy)
	_consume_power_stacks(power_stacks_needed)
	return true


func _get_power_stacks_needed(missing_energy: float) -> int:
	if missing_energy <= 0.0:
		return 0
	if energy_per_power_stack <= 0.0:
		return 0
	return int(ceil(missing_energy / energy_per_power_stack))


func _get_power_stack_count() -> int:
	var power_instance: StatusInstance = _get_power_status_instance()
	if power_instance == null:
		return 0
	return max(power_instance.stacks, 0)


func _consume_power_stacks(amount: int) -> int:
	if entity == null or entity.status_controller == null:
		return 0
	return entity.status_controller.consume_status_stacks(power_status_id, amount)


func _get_power_status_instance() -> StatusInstance:
	if entity == null or entity.status_controller == null:
		return null
	if power_status_id == &"":
		return null
	return entity.status_controller.get_status(power_status_id)


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
