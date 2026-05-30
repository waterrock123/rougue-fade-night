class_name StatsController
extends Node

@export var stats_data: StatsData

const PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

var final_stats: Dictionary = {}
var modifiers: Array[Modifier] = []
var effect_modifiers: Dictionary = {}
var outgoing_damage_bonus_modifiers: Dictionary = {}
var current_health: float = 0.0
var current_energy: float = 0.0
var player_build: PlayerBuild

@onready var modifier_handler: ModifierHandler = get_node_or_null("../ModifierHandler") as ModifierHandler
@onready var entity: Entity = get_parent() as Entity


func _ready() -> void:
	if stats_data != null:
		stats_data = stats_data.duplicate(true)

	if modifier_handler != null:
		modifier_handler.bind_stats_controller(self)

	recompute_stats()

	if current_health <= 0.0:
		current_health = get_stat("max_health")
	if current_energy <= 0.0:
		current_energy = get_stat("max_energy")

	_sync_entity_stats(true)
	_sync_player_build()


# 将 StatsController 绑定到 PlayerBuild，使其可以在非战斗场景中独立工作。
func bind_player_build(new_player_build: PlayerBuild) -> void:
	player_build = new_player_build
	if player_build == null:
		return

	if player_build.player_stats != null:
		stats_data = player_build.player_stats.duplicate(true)

	var saved_current_health := player_build.current_health
	var saved_current_energy := player_build.current_energy
	var had_previous_health_stat := get_stat("max_health") > 0.0
	var had_previous_energy_stat := get_stat("max_energy") > 0.0

	current_health = player_build.current_health
	current_energy = player_build.current_energy

	recompute_stats()

	var max_health := get_stat("max_health")
	var max_energy := get_stat("max_energy")

	if not had_previous_health_stat:
		if saved_current_health > 0.0:
			current_health = min(saved_current_health, max_health)
		else:
			current_health = max_health
	else:
		current_health = min(current_health, max_health)

	if not had_previous_energy_stat:
		if saved_current_energy > 0.0:
			current_energy = min(saved_current_energy, max_energy)
		else:
			current_energy = max_energy
	else:
		current_energy = min(current_energy, max_energy)

	_sync_player_build()
	EventBus.attribute_update.emit()


# 用 ModifierHandler 提供的修饰器整体覆盖运行时修饰器列表。
func set_modifiers(new_modifiers: Array[Modifier]) -> void:
	modifiers = new_modifiers.duplicate()
	recompute_stats()


# 添加单个运行时修饰器。
func add_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	modifiers.append(modifier)
	recompute_stats()


# 移除单个运行时修饰器。
func remove_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	modifiers.erase(modifier)
	recompute_stats()


# 注册某个外部系统提供的一组修饰器。
func set_effect_modifiers(source_key: Variant, new_modifiers: Array[Modifier]) -> void:
	if source_key == null:
		return

	var normalized_modifiers: Array[Modifier] = []
	for modifier in new_modifiers:
		if modifier != null:
			normalized_modifiers.append(modifier)

	effect_modifiers[source_key] = normalized_modifiers
	recompute_stats()


# 清除某个外部来源注册的修饰器。
func clear_effect_modifiers(source_key: Variant) -> void:
	if source_key == null:
		return

	if effect_modifiers.has(source_key):
		effect_modifiers.erase(source_key)
		recompute_stats()


# 注册某个状态/被动提供的出伤加成。
func set_outgoing_damage_bonus_modifier(source_key: Variant, modifier_data: Dictionary) -> void:
	if source_key == null:
		return
	outgoing_damage_bonus_modifiers[str(source_key)] = modifier_data.duplicate(true)


# 清除某个来源注册的出伤加成。
func clear_outgoing_damage_bonus_modifier(source_key: Variant) -> void:
	if source_key == null:
		return
	outgoing_damage_bonus_modifiers.erase(str(source_key))


# 对外统一读取最终属性。
func get_stat(stat_name: StringName, default_value: float = 0.0) -> float:
	return float(final_stats.get(stat_name, default_value))


# 重算最终属性。
func recompute_stats() -> void:
	if stats_data == null:
		final_stats.clear()
		return

	var previous_max_health := get_stat("max_health")
	var previous_max_energy := get_stat("max_energy")
	var primary_stats := _build_primary_stats(stats_data)
	var direct_modifiers: Array[Modifier] = []

	for modifier in _get_all_modifiers():
		if _is_primary_stat_modifier(modifier):
			_apply_modifier(primary_stats, modifier)
		else:
			direct_modifiers.append(modifier)

	var final := _build_derived_stats(stats_data, primary_stats)
	for primary_stat in PRIMARY_STATS:
		final[primary_stat] = primary_stats.get(primary_stat, 0.0)

	for modifier in direct_modifiers:
		_apply_modifier(final, modifier)

	final_stats = final
	_clamp_resources(previous_max_health, previous_max_energy)
	_sync_entity_stats(false)
	_sync_player_build()
	EventBus.attribute_update.emit()


# 构建一级属性基础值。
func _build_primary_stats(data: StatsData) -> Dictionary:
	return {
		"strength": float(data.strength),
		"dexterity": float(data.dexterity),
		"intelligence": float(data.intelligence),
		"constitution": float(data.constitution),
		"speed": float(data.speed),
		"charm": float(data.charm),
		"luck": float(data.luck),
	}


# 用一级属性推导战斗中真正使用的派生属性。
func _build_derived_stats(data: StatsData, primary_stats: Dictionary) -> Dictionary:
	var constitution := float(primary_stats.get("constitution", 0.0))
	var intelligence := float(primary_stats.get("intelligence", 0.0))
	var speed := float(primary_stats.get("speed", 0.0))
	var luck := float(primary_stats.get("luck", 0.0))

	return {
		"max_health": data.base_max_health + constitution * 5.0,
		"max_energy": data.base_max_energy + intelligence * 3.0,
		"move_speed": data.base_move_speed + speed * 10.0,
		"energy_regen_tick_value": data.base_energy_regen_tick_value + intelligence,
		"crit_chance": data.base_crit_chance + luck * 0.002,
		"crit_damage": data.base_crit_damage,
		"dodge_rate": data.base_dodge_rate + speed * 0.001,
		"damage_reduction_rate": data.base_damage_reduction_rate,
		"static_damage_reduction": float(data.base_static_damage_reduction),
		"cooldown_reduction": data.base_cooldown_reduction + speed * 0.002,
		"projectile_range_bonus_rate": 0.0,
	}


# 汇总所有来源的修饰器。
func _get_all_modifiers() -> Array[Modifier]:
	var all_modifiers: Array[Modifier] = modifiers.duplicate()

	for source_key in effect_modifiers.keys():
		var source_modifiers = effect_modifiers[source_key] as Array
		for modifier in source_modifiers:
			if modifier != null:
				all_modifiers.append(modifier)

	return all_modifiers


# 判断一条修饰器是不是作用于一级属性。
func _is_primary_stat_modifier(modifier: Modifier) -> bool:
	if modifier == null:
		return false

	return PRIMARY_STATS.has(StringName(modifier.stat))


# 将单个修饰器应用到属性字典上。
func _apply_modifier(final: Dictionary, modifier: Modifier) -> void:
	if modifier == null or not modifier.is_active():
		return

	var stat_name := StringName(modifier.stat)
	if not final.has(stat_name):
		return

	match modifier.modifier_type:
		Modifier.ModifierType.FLAT:
			final[stat_name] += modifier.value
		Modifier.ModifierType.PERCENT:
			final[stat_name] *= 1.0 + modifier.value


# 处理攻击方造成伤害时的结算。
func process_outgoing_damage(damage_data: DamageData) -> DamageData:
	if damage_data == null:
		return null

	damage_data.final_damage = damage_data.base_damage
	damage_data.final_damage += _get_outgoing_damage_bonus(damage_data)

	if damage_data.can_crit and not damage_data.is_crit:
		if randf() <= get_stat("crit_chance"):
			damage_data.is_crit = true

	damage_data.crit_multiplier = get_stat("crit_damage", damage_data.crit_multiplier)
	if damage_data.is_crit:
		damage_data.final_damage *= damage_data.crit_multiplier

	return damage_data


# 处理防守方受到伤害时的减伤结算。
func process_incoming_damage(damage_data: DamageData) -> DamageData:
	if damage_data == null:
		return null

	var damage := damage_data.final_damage
	damage -= get_stat("static_damage_reduction")
	damage = max(damage, 0.0)

	var damage_reduction_rate: float = clamp(get_stat("damage_reduction_rate"), 0.0, 1.0)
	damage *= 1.0 - damage_reduction_rate

	damage_data.final_damage = max(damage, 0.0)
	return damage_data


# 从 DamageData 上挂载的成长规则里计算额外伤害。
func _get_outgoing_damage_bonus(damage_data: DamageData) -> float:
	if damage_data == null:
		return 0.0

	var bonus := 0.0
	if damage_data.scaling_rule != null:
		bonus += max(damage_data.scaling_rule.get_bonus_damage(self, damage_data), 0.0)
	bonus += _get_registered_outgoing_damage_bonus(damage_data)
	return max(bonus, 0.0)


# 计算由状态/被动注册的额外出伤，例如暴怒的“初始技能附带体质伤害”。
func _get_registered_outgoing_damage_bonus(damage_data: DamageData) -> float:
	var bonus := 0.0
	for modifier_data in outgoing_damage_bonus_modifiers.values():
		if not _outgoing_damage_modifier_matches(damage_data, modifier_data):
			continue

		bonus += float(modifier_data.get("flat_bonus", 0.0))
		var formula := str(modifier_data.get("flat_bonus_formula", ""))
		if not formula.is_empty():
			bonus += _evaluate_damage_bonus_formula(formula, damage_data)
		bonus += damage_data.base_damage * float(modifier_data.get("percent_bonus", 0.0))

	return bonus


func _outgoing_damage_modifier_matches(damage_data: DamageData, modifier_data: Dictionary) -> bool:
	var target_ids: Array = modifier_data.get("target_ability_ids", [])
	if not target_ids.is_empty() and not target_ids.has(damage_data.source_ability_id):
		return false

	var target_slots: Array = modifier_data.get("target_slot_indices", [])
	if not target_slots.is_empty() and not target_slots.has(damage_data.source_ability_slot_index):
		return false

	var required_tags: Array = modifier_data.get("required_tags", [])
	for required_tag in required_tags:
		if not damage_data.tags.has(str(required_tag)):
			return false

	var required_damage_types: Array = modifier_data.get("required_damage_types", [])
	for required_damage_type in required_damage_types:
		if not damage_data.damage_types.has(int(required_damage_type)):
			return false

	return true


func _evaluate_damage_bonus_formula(formula: String, damage_data: DamageData) -> float:
	var expression := Expression.new()
	var values := {
		"base_damage": damage_data.base_damage,
		"final_damage": damage_data.final_damage,
		"strength": get_stat("strength"),
		"dexterity": get_stat("dexterity"),
		"intelligence": get_stat("intelligence"),
		"constitution": get_stat("constitution"),
		"speed": get_stat("speed"),
		"charm": get_stat("charm"),
		"luck": get_stat("luck"),
	}
	var input_names: PackedStringArray = []
	var input_values: Array = []
	for key in values.keys():
		input_names.append(String(key))
		input_values.append(values[key])

	if expression.parse(formula, input_names) != OK:
		push_warning("StatsController damage bonus formula parse failed: %s" % formula)
		return 0.0

	var result = expression.execute(input_values, self, true)
	if expression.has_execute_failed():
		push_warning("StatsController damage bonus formula execute failed: %s" % formula)
		return 0.0

	return max(float(result), 0.0)


# 最大生命/能量变化后，夹取当前资源值。
func _clamp_resources(previous_max_health: float, previous_max_energy: float) -> void:
	var new_max_health := get_stat("max_health")
	var new_max_energy := get_stat("max_energy")

	if previous_max_health <= 0.0:
		current_health = new_max_health
	else:
		var health_ratio = clamp(current_health / previous_max_health, 0.0, 1.0)
		current_health = new_max_health * health_ratio

	if previous_max_energy <= 0.0:
		current_energy = new_max_energy
	else:
		current_energy = min(current_energy, new_max_energy)


# 把运行时属性同步回父实体。
func _sync_entity_stats(force_fill_resources: bool) -> void:
	if entity == null:
		return

	entity.max_health = get_stat("max_health")
	entity.max_energy = get_stat("max_energy")
	entity.energy_region_tick_value = get_stat("energy_regen_tick_value")

	if force_fill_resources:
		entity.current_health = entity.max_health
		entity.current_energy = entity.max_energy
		current_health = entity.current_health
		current_energy = entity.current_energy
	else:
		entity.current_health = current_health
		entity.current_energy = current_energy

	entity.apply_runtime_stats(final_stats)


# 把当前生命、能量和属性计算结果写回 PlayerBuild。
func _sync_player_build() -> void:
	if player_build == null:
		return

	player_build.current_health = current_health
	player_build.current_energy = current_energy


func sync_runtime_resources() -> void:
	_sync_player_build()
