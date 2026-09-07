class_name PassiveDamageChancePrimaryStatsEffect
extends PassiveSkillEffect

## 造成伤害时按概率提升属性，击杀敌人会提高下一次判定的概率。
## 属性提升只写入当前战斗的 StatsController，战斗场景销毁后会自动清除。
@export_range(0.0, 1.0, 0.01) var initial_chance: float = 0.02
@export_range(0.0, 1.0, 0.01) var kill_chance_bonus: float = 0.10
@export_range(0.0, 1.0, 0.01) var success_reset_chance: float = 0.02
@export var stat_amount: int = 1
@export var grant_all_primary_stats: bool = false
@export var candidate_stats: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

var active_contexts: Dictionary = {}
var current_chances: Dictionary = {}
var damage_callbacks: Dictionary = {}
var runtime_stat_bonuses: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.caster == null:
		return
	if not context.caster.is_in_group("player"):
		return

	var context_key: String = _get_context_key(context)
	active_contexts[context_key] = context
	current_chances[context_key] = clamp(initial_chance, 0.0, 1.0)
	runtime_stat_bonuses[context_key] = {}

	var callback: Callable = Callable(self, "_on_damage_dealt").bind(context_key)
	damage_callbacks[context_key] = callback
	if not context.caster.damage_dealt.is_connected(callback):
		context.caster.damage_dealt.connect(callback)

	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	var context_key: String = _get_context_key(context)
	var callback: Callable = damage_callbacks.get(context_key, Callable())
	if callback.is_valid() and is_instance_valid(context.caster):
		if context.caster.damage_dealt.is_connected(callback):
			context.caster.damage_dealt.disconnect(callback)

	damage_callbacks.erase(context_key)
	active_contexts.erase(context_key)
	current_chances.erase(context_key)
	runtime_stat_bonuses.erase(context_key)
	if context.stats_controller != null:
		context.stats_controller.clear_effect_modifiers(context.effect_key)
	if active_contexts.is_empty() and EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _on_damage_dealt(damage_data: DamageData, context_key: String) -> void:
	if damage_data == null or damage_data.final_damage <= 0.0:
		return
	if not active_contexts.has(context_key):
		return

	var chance: float = clamp(float(current_chances.get(context_key, initial_chance)), 0.0, 1.0)
	if randf() >= chance:
		return

	var context: SkillContext = active_contexts[context_key] as SkillContext
	if context == null:
		return

	_grant_stats(context)
	current_chances[context_key] = clamp(success_reset_chance, 0.0, 1.0)


func _on_enemy_killed(_enemy: Entity, killer: Entity) -> void:
	if killer == null:
		return

	for context_key: String in active_contexts.keys():
		var context: SkillContext = active_contexts[context_key] as SkillContext
		if context == null or context.caster != killer:
			continue

		var chance: float = float(current_chances.get(context_key, initial_chance))
		current_chances[context_key] = clamp(chance + kill_chance_bonus, 0.0, 1.0)


func _grant_stats(context: SkillContext) -> void:
	if context.stats_controller == null:
		return
	if candidate_stats.is_empty() or stat_amount == 0:
		return

	var context_key: String = _get_context_key(context)
	var stat_bonuses: Dictionary = runtime_stat_bonuses.get(context_key, {}) as Dictionary
	if grant_all_primary_stats:
		for stat_name: StringName in candidate_stats:
			_add_runtime_stat(stat_bonuses, stat_name)
	else:
		var stat_index: int = randi_range(0, candidate_stats.size() - 1)
		_add_runtime_stat(stat_bonuses, candidate_stats[stat_index])

	runtime_stat_bonuses[context_key] = stat_bonuses
	_apply_runtime_modifiers(context)


func _add_runtime_stat(stat_bonuses: Dictionary, stat_name: StringName) -> void:
	if not _is_primary_stat(stat_name):
		return
	var current_value: int = int(stat_bonuses.get(stat_name, 0))
	stat_bonuses[stat_name] = current_value + stat_amount


func _apply_runtime_modifiers(context: SkillContext) -> void:
	if context == null or context.stats_controller == null:
		return

	var context_key: String = _get_context_key(context)
	var stat_bonuses: Dictionary = runtime_stat_bonuses.get(context_key, {}) as Dictionary
	var modifiers: Array[Modifier] = []
	for stat_name: StringName in stat_bonuses.keys():
		var amount: float = float(stat_bonuses[stat_name])
		modifiers.append(Modifier.create_flat(stat_name, amount, context.effect_key))

	context.stats_controller.set_effect_modifiers(context.effect_key, modifiers)


func _is_primary_stat(stat_name: StringName) -> bool:
	return [
		&"strength",
		&"dexterity",
		&"intelligence",
		&"constitution",
		&"speed",
		&"charm",
		&"luck",
	].has(stat_name)


func _get_context_key(context: SkillContext) -> String:
	var controller_id: int = 0
	if context.skill_controller != null:
		controller_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(controller_id), str(context.effect_key)]
