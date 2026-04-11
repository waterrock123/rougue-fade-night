class_name StatsController
extends Node

@export var stats_data: StatsData

var final_stats: Dictionary = {}
var modifiers: Array[Modifier] = []
var current_health: float = 0.0
var current_energy: float = 0.0

@onready var modifier_handler: ModifierHandler = get_node_or_null("../ModifierHandler") as ModifierHandler
@onready var entity: Entity = get_parent() as Entity


# 初始化运行时属性：
# 1. 复制初始化数据，避免多个实体共用同一份 Resource
# 2. 绑定 ModifierHandler
# 3. 首次计算最终属性并同步给父实体
func _ready() -> void:
	if stats_data != null:
		stats_data = stats_data.duplicate(true)

	if modifier_handler != null:
		modifier_handler.bind_stats_controller(self)

	recompute_stats()
	current_health = get_stat("max_health")
	current_energy = get_stat("max_energy")
	_sync_entity_stats(true)


# 使用一整组修饰器替换当前修饰器列表，并立即重算属性。
func set_modifiers(new_modifiers: Array[Modifier]) -> void:
	modifiers = new_modifiers.duplicate()
	recompute_stats()


# 添加单个修饰器，适合运行时临时添加 buff / debuff。
func add_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	modifiers.append(modifier)
	recompute_stats()


# 移除单个修饰器，并重新计算最终属性。
func remove_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	modifiers.erase(modifier)
	recompute_stats()


# 按名字读取最终属性。
# 如果该属性不存在，则返回传入的默认值。
func get_stat(stat_name: StringName, default_value: float = 0.0) -> float:
	return float(final_stats.get(stat_name, default_value))


# 重新计算最终属性：
# 先根据初始化数据生成初始值，再依次叠加所有修饰器，
# 最后处理当前生命/能量上限变化，并同步回父实体。
func recompute_stats() -> void:
	if stats_data == null:
		final_stats.clear()
		return

	var previous_max_health := get_stat("max_health")
	var previous_max_energy := get_stat("max_energy")
	var final := _build_base_stats(stats_data)

	for modifier in modifiers:
		_apply_modifier(final, modifier)

	final_stats = final
	_clamp_resources(previous_max_health, previous_max_energy)
	_sync_entity_stats(false)


# 基础换算入口：
# 把 StatsData 中的初始化数据转换成运行时真正参与战斗计算的属性字典。
func _build_base_stats(data: StatsData) -> Dictionary:
	return {
		"max_health": data.base_max_health + data.constitution * 5.0,
		"max_energy": data.base_max_energy + data.intelligence * 3.0,
		"move_speed": data.base_move_speed + data.speed * 10.0,
		"energy_regen_tick_value": data.base_energy_regen_tick_value + data.intelligence,
		"crit_chance": data.base_crit_chance + data.luck * 0.002,
		"crit_damage": data.base_crit_damage,
		"dodge_rate": data.base_dodge_rate + data.speed * 0.001,
		"damage_reduction_rate": data.base_damage_reduction_rate,
		"static_damage_reduction": float(data.base_static_damage_reduction),
		"cooldown_reduction": data.base_cooldown_reduction + data.speed * 0.002,
		"strength": float(data.strength),
		"dexterity": float(data.dexterity),
		"intelligence": float(data.intelligence),
		"constitution": float(data.constitution),
		"speed": float(data.speed),
		"charm": float(data.charm),
		"luck": float(data.luck),
	}


# 应用单个修饰器到最终属性字典。
# flat 表示直接加值，percent 表示按比例乘算。
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


# 当最大生命或最大能量变化后，
# 确保当前生命/能量不会超过新的上限。
func _clamp_resources(previous_max_health: float, previous_max_energy: float) -> void:
	var new_max_health := get_stat("max_health")
	var new_max_energy := get_stat("max_energy")

	if previous_max_health <= 0.0:
		current_health = new_max_health
	else:
		current_health = min(current_health, new_max_health)

	if previous_max_energy <= 0.0:
		current_energy = new_max_energy
	else:
		current_energy = min(current_energy, new_max_energy)


# 把 StatsController 中计算出的结果同步到父实体。
# 计算负责统一数据，行为映射交给 Entity / Player / Enemy 自己处理。
func _sync_entity_stats(force_fill_resources: bool) -> void:
	if entity == null:
		return

	entity.max_health = get_stat("max_health")
	entity.max_energy = get_stat("max_energy")
	entity.energy_region_tick_value = get_stat("energy_regen_tick_value")
	entity.apply_runtime_stats(final_stats)

	if force_fill_resources:
		entity.current_health = entity.max_health
		entity.current_energy = entity.max_energy
		current_health = entity.current_health
		current_energy = entity.current_energy
	else:
		entity.current_health = current_health
		entity.current_energy = current_energy
