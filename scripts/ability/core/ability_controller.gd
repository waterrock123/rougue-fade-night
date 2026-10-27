class_name AbilityController
extends Node

signal ability_triggered(ability: Ability, caster: Entity)
## 已支付成本、尚未执行任何组件时发出；可修改本次伤害快照。
signal cast_prepared(context: AbilityContext)
signal channel_completed(context: AbilityContext)
## 操作层事件与正式施法分开，供教学/UI监听，不改变冷却或付费流程。
signal ability_preview_started(ability: Ability, caster: Entity)
signal ability_preview_released(ability: Ability, caster: Entity)
signal ability_preview_cancelled(ability: Ability, caster: Entity)

## 下一次非基础主动技能专用，不在预览、检查资源或失败施法时消耗。
var next_cast_modifiers: Dictionary = {}

var abilities: Array[Ability] = []
var cooldowns: Dictionary = {}
var cooldown_modifiers: Dictionary = {}
## 按被动来源保存施法修正，技能栏重建后仍能读取；移除来源后立即失效。
var cast_tuning_modifiers: Dictionary = {}
var runtime_abilities: Array[Ability] = []
var runtime_ability_sources: Dictionary = {}
var previewing_ability: Ability
## 按来源记录局部技能禁用，避免持续技能把整个人物锁住。
var cast_block_modifiers: Dictionary = {}

var entity: Entity
## 训练用运行时覆盖，负数表示正常冷却；不写入技能资源。
var training_cooldown_override: float = -1.0

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


## 长按输入专用入口：只自动续放无需“按住瞄准、松开释放”的技能。
func trigger_held_ability_by_idx(idx: int) -> bool:
	if idx < 0 or idx >= abilities.size():
		return false

	var ability: Ability = abilities[idx]
	if ability == null or ability.has_cast_preview():
		return false
	# 自动续放时，等待冷却是正常流程，不提示“冷却中”。
	if float(cooldowns.get(ability, 0.0)) > 0.0:
		return false
	return request_player_cast(ability)


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


## 查询当前实际携带的技能；不要求冷却/法力可释放，不把未携带的仓备技能算进去。
func get_abilities_with_elements(required: Array[StringName], require_all: bool = false, include_basic_attack: bool = true) -> Array[Ability]:
	var result: Array[Ability] = []
	for ability: Ability in abilities:
		if not is_instance_valid(ability):
			continue
		var basic: bool = ability.skill_data.is_basic_attack if ability.skill_data != null else abilities.find(ability) == 0
		if not include_basic_attack and basic:
			continue
		if ability.matches_element_tags(required, require_all):
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
	if _is_cast_blocked(ability):
		return false

	var cd = cooldowns.get(ability, 0.0)
	return cd == 0 and _has_enough_ability_energy(get_modified_energy_cost(ability)) and ability.can_pay_activation_costs(entity)


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


func trigger_ability(ability: Ability, charge_ratio: float = 0.0) -> bool:
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
	if _is_cast_blocked(ability):
		return false
	if not _has_enough_ability_energy(get_modified_energy_cost(ability)):
		return false
	if not ability.can_pay_activation_costs(entity):
		return false
	var paid_context: AbilityContext = AbilityContext.new(entity, ability)
	if not ability.pay_activation_costs(entity, paid_context):
		return false

	if not _spend_ability_energy(get_modified_energy_cost(ability)):
		return false

	ability.activate(entity, charge_ratio, paid_context)
	ability_triggered.emit(ability, entity)
	cooldowns[ability] = _get_modified_cooldown(ability)
	return true


## 只有玩家的主动输入走此入口；AI、装备自动触发仍使用静默 trigger_ability。
func request_player_cast(ability: Ability, charge_ratio: float = 0.0) -> bool:
	if not is_instance_valid(ability) or not is_instance_valid(entity):
		return false
	if not _can_be_cast(ability):
		_show_ability_block_reason(ability)
		return false
	if trigger_ability(ability, charge_ratio):
		return true
	_show_ability_block_reason(ability)
	return false


## 与实际施法成本一致，包括下次施法折扣、电力替代能量和弹药箱补给。
func get_cast_block_info(ability: Ability) -> Dictionary:
	if not is_instance_valid(ability) or not is_instance_valid(entity) or entity.is_dead:
		return {}
	if not entity.can_act():
		return {"key": "control", "message": "当前无法行动，暂时不能释放技能"}
	if _is_cast_blocked(ability):
		return {"key": "disabled", "message": "当前状态下无法释放该技能"}
	var remaining: float = float(cooldowns.get(ability, 0.0))
	if remaining > 0.0:
		return {"key": "cooldown", "message": "技能冷却中，还需%.1f秒" % remaining}
	var cost: float = get_modified_energy_cost(ability)
	if not _has_enough_ability_energy(cost):
		return {"key": "energy", "message": "能量不足，施放需要%s点能量" % str(cost)}
	var reason: String = ability.get_activation_block_reason(entity)
	if not reason.is_empty():
		return {"key": "material", "message": reason}
	return {}


func set_next_cast_modifier(source_key: String, data: Dictionary) -> void:
	next_cast_modifiers[source_key] = data.duplicate(true)


func clear_next_cast_modifier(source_key: String) -> void:
	next_cast_modifiers.erase(source_key)


func is_basic_ability(ability: Ability) -> bool:
	return ability.skill_data.is_basic_attack if ability.skill_data != null else abilities.find(ability) == 0


## 与检查、扣费统一使用同一份折扣；普通攻击不使用吟唱保留的优惠。
func get_modified_energy_cost(ability: Ability) -> float:
	var cost: float = ability.energy_cost
	if not is_basic_ability(ability):
		for data: Dictionary in next_cast_modifiers.values():
			cost -= maxf(float(data.get("energy_reduction", 0.0)), 0.0)
	return maxf(cost, 0.0)


func prepare_cast_context(context: AbilityContext) -> void:
	context.cast_record.is_basic_attack = is_basic_ability(context.ability)
	if not context.cast_record.is_basic_attack:
		for data: Dictionary in next_cast_modifiers.values():
			context.cast_record.damage_multiplier *= maxf(float(data.get("damage_multiplier", 1.0)), 0.0)
		next_cast_modifiers.clear()
	cast_prepared.emit(context)


## 立即削减剩余冷却，同时更新 UI 读取的值；不影响之后释放的基础冷却。
func reduce_remaining_cooldown(ability: Ability, reduction_ratio: float) -> void:
	if not is_instance_valid(ability) or not abilities.has(ability):
		return
	var remaining: float = maxf(float(cooldowns.get(ability, 0.0)), 0.0)
	remaining *= 1.0 - clampf(reduction_ratio, 0.0, 1.0)
	cooldowns[ability] = remaining
	ability.current_cooldown = remaining


## 固定秒数削减，与按比例削减分开，避免把1秒误解释成清空冷却。
func reduce_remaining_cooldown_seconds(ability: Ability, seconds: float) -> void:
	if not is_instance_valid(ability) or not abilities.has(ability):
		return
	var remaining: float = maxf(float(cooldowns.get(ability, 0.0)) - maxf(seconds, 0.0), 0.0)
	cooldowns[ability] = remaining
	ability.current_cooldown = remaining


# 注册一个由状态/被动提供的冷却修正。
func set_cooldown_modifier(source_key: Variant, modifier_data: Dictionary) -> void:
	if source_key == null:
		return
	cooldown_modifiers[str(source_key)] = modifier_data.duplicate(true)
	if bool(modifier_data.get("reset_current_cooldowns", false)):
		for ability: Ability in abilities:
			if is_instance_valid(ability) and _cooldown_modifier_matches(ability, abilities.find(ability), modifier_data):
				reduce_remaining_cooldown(ability, 1.0)


# 移除指定来源的冷却修正。
func clear_cooldown_modifier(source_key: Variant) -> void:
	if source_key == null:
		return
	cooldown_modifiers.erase(str(source_key))


## 复用冷却修正的目标筛选规则，支持按技能id或栏位限定作用范围。
func set_cast_tuning_modifier(source_key: Variant, data: Dictionary) -> void:
	cast_tuning_modifiers[str(source_key)] = data.duplicate(true)


func clear_cast_tuning_modifier(source_key: Variant) -> void:
	cast_tuning_modifiers.erase(str(source_key))
	# 被动替换时中断旧预览，避免旧分支的蓄力状态遗留。
	if is_instance_valid(previewing_ability) and not previewing_ability.has_cast_preview():
		cancel_ability_preview()


func get_cast_tuning(ability: Ability) -> Dictionary:
	var result: Dictionary = {"damage_multiplier": 1.0, "projectile_count": 0, "charge_enabled": false}
	for data: Dictionary in cast_tuning_modifiers.values():
		if not _cooldown_modifier_matches(ability, abilities.find(ability), data):
			continue
		result["damage_multiplier"] *= maxf(float(data.get("damage_multiplier", 1.0)), 0.0)
		result["projectile_count"] = maxi(int(result["projectile_count"]), int(data.get("projectile_count", 0)))
		result["charge_enabled"] = bool(result["charge_enabled"]) or bool(data.get("charge_enabled", false))
	return result


## 状态可只禁用基础攻击或指定技能，所有输入/AI入口都会经过统一校验。
func set_cast_block_modifier(source_key: String, modifier_data: Dictionary) -> void:
	cast_block_modifiers[source_key] = modifier_data.duplicate(true)
	if is_instance_valid(previewing_ability) and _is_cast_blocked(previewing_ability):
		cancel_ability_preview()


func clear_cast_block_modifier(source_key: String) -> void:
	cast_block_modifiers.erase(source_key)


func _is_cast_blocked(ability: Ability) -> bool:
	for data: Dictionary in cast_block_modifiers.values():
		if bool(data.get("block_all", false)):
			return true
		var blocked_ids: Array = data.get("ability_ids", [])
		if blocked_ids.has(ability.id):
			return true
		var is_basic: bool = ability.skill_data.is_basic_attack if ability.skill_data != null else abilities.find(ability) == 0
		if bool(data.get("block_basic_attack", false)) and is_basic:
			return true
	return false


func begin_ability_preview(ability: Ability) -> void:
	if ability == null or entity == null:
		return
	# 没有预览组件的旧技能仍然保持原逻辑：按下按键就直接释放。
	if not ability.has_cast_preview():
		request_player_cast(ability)
		return
	if not _can_be_cast(ability):
		_show_ability_block_reason(ability)
		return

	# 同一时间只允许预览一个技能，避免多个指示器叠在一起。
	cancel_ability_preview()
	previewing_ability = ability
	ability.begin_cast_preview(entity)
	ability_preview_started.emit(ability, entity)


func release_ability_preview(ability: Ability) -> void:
	if ability == null or ability != previewing_ability:
		return

	# 松开按键时关闭指示器，再走正式释放流程，冷却和能量仍由 trigger_ability 统一校验。
	var released_charge: float = ability.preview_context.charge_ratio if ability.preview_context != null else 0.0
	ability.end_cast_preview()
	previewing_ability = null
	ability_preview_released.emit(ability, entity)
	request_player_cast(ability, released_charge)


func cancel_ability_preview() -> void:
	if previewing_ability != null:
		var cancelled: Ability = previewing_ability
		cancelled.end_cast_preview()
		previewing_ability = null
		ability_preview_cancelled.emit(cancelled, entity)


func _show_ability_block_reason(ability: Ability) -> void:
	if not is_instance_valid(ability) or not is_instance_valid(entity) or not entity is Player or entity.is_dead:
		return
	var info: Dictionary = get_cast_block_info(ability)
	var reason: String = str(info.get("message", "当前无法释放技能，请重试"))
	FloatText.show_action_tip(reason, "skill:%s:%s" % [str(ability.id), str(info.get("key", "failed"))])


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


## 供蓄力等组件读取最终冷却时长；不改变剩余冷却，也不消耗施法资源。
func get_effective_cooldown(ability: Ability) -> float:
	if not is_instance_valid(ability):
		return 0.0
	return _get_modified_cooldown(ability)


func _get_modified_cooldown(ability: Ability) -> float:
	var fixed_cooldown: float = _get_fixed_cooldown(ability)
	if fixed_cooldown >= 0.0:
		return fixed_cooldown
	if training_cooldown_override >= 0.0:
		return maxf(training_cooldown_override, 0.1)
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


## 显式固定冷却不受常规最低0.05秒或减CD修正影响；多个来源取更小值。
func _get_fixed_cooldown(ability: Ability) -> float:
	var result: float = -1.0
	for data: Dictionary in cooldown_modifiers.values():
		var override_value: float = float(data.get("cooldown_override", -1.0))
		if override_value < 0.0 or not _cooldown_modifier_matches(ability, abilities.find(ability), data):
			continue
		result = override_value if result < 0.0 else minf(result, override_value)
	return result


func _cooldown_modifier_matches(ability: Ability, slot_index: int, modifier_data: Dictionary) -> bool:
	var excluded_slots: Array = modifier_data.get("excluded_slot_indices", [])
	if excluded_slots.has(slot_index):
		return false
	var target_ids: Array = modifier_data.get("target_ability_ids", [])
	if not target_ids.is_empty():
		return target_ids.has(ability.id)

	var target_slots: Array = modifier_data.get("target_slot_indices", [])
	if not target_slots.is_empty():
		return target_slots.has(slot_index)

	return true
