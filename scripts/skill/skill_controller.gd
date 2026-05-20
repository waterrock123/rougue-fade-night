class_name SkillController
extends Node

var player_build: PlayerBuild
var run_stats: RunStats
var passive_effect_keys: Array[StringName] = []
var active_passive_effects: Array[Dictionary] = []

@onready var stats_controller: StatsController = get_node_or_null("../StatsController") as StatsController
@onready var status_controller: StatusController = get_node_or_null("../StatusController") as StatusController
@onready var ability_controller: AbilityController = get_node_or_null("../AbilityController") as AbilityController
@onready var entity: Entity = get_parent() as Entity


func bind_player_build(new_player_build: PlayerBuild) -> void:
	player_build = new_player_build
	run_stats = _resolve_run_stats()
	refresh_all_skills()


# 同时刷新主动和被动技能。
func refresh_all_skills() -> void:
	refresh_passive_skills()
	refresh_active_skills()


# 主动技能负责把 Ability 场景注册到 AbilityController。
func refresh_active_skills() -> void:
	if ability_controller == null:
		return

	ability_controller.clear_runtime_abilities()
	if player_build == null:
		return

	var slot_index := 0
	for entry in player_build.owned_active_skills:
		if entry == null or not entry.is_equipped:
			continue

		# 普通技能受技能栏上限限制；装备/状态给的临时技能视作额外技能，允许挂到后续槽位。
		if not entry.is_temporary and slot_index >= player_build.active_skill_slot_limit:
			continue

		var skill_data := entry.skill_data as ActiveSkillData
		if skill_data == null or skill_data.ability_scene == null:
			continue

		var runtime_ability := ability_controller.register_runtime_ability(
			skill_data.ability_scene,
			_build_active_source_key(entry)
		)
		if runtime_ability != null:
			runtime_ability.runtime_slot_index = slot_index
			runtime_ability.apply_skill_data(skill_data, entry)

		slot_index += 1


# 被动技能负责把效果应用到 StatsController、StatusController 等运行时系统。
func refresh_passive_skills() -> void:
	_clear_passive_effects()
	if run_stats != null:
		run_stats.reset_rest_period_gold_modifiers()

	if player_build == null:
		return

	for entry in player_build.owned_passive_skills:
		if entry == null:
			continue

		var passive_data := entry.skill_data as PassiveSkillData
		if passive_data == null:
			continue

		for effect_index in range(passive_data.effects.size()):
			var effect := passive_data.effects[effect_index]
			if effect == null:
				continue

			var context := _build_context(entry, effect_index)
			effect.apply(context)
			active_passive_effects.append({
				"effect": effect,
				"context": context,
			})


func grant_active_skill(skill_data: ActiveSkillData) -> SkillEntry:
	if player_build == null:
		return null

	var entry := player_build.grant_active_skill(skill_data)
	refresh_active_skills()
	return entry


func grant_passive_skill(skill_data: PassiveSkillData) -> SkillEntry:
	if player_build == null:
		return null

	var entry := player_build.grant_passive_skill(skill_data)
	refresh_passive_skills()
	return entry


func upgrade_skill_entry(skill_entry: SkillEntry) -> void:
	if skill_entry == null:
		return

	skill_entry.level_up()
	refresh_all_skills()


func _build_context(skill_entry: SkillEntry, effect_index: int = -1) -> SkillContext:
	var context := SkillContext.new()
	context.player_build = player_build
	context.run_stats = run_stats
	context.skill_entry = skill_entry
	context.skill_data = skill_entry.skill_data if skill_entry != null else null
	context.caster = entity
	context.skill_controller = self
	context.stats_controller = stats_controller
	context.status_controller = status_controller
	context.ability_controller = ability_controller
	context.effect_key = _build_passive_effect_key(skill_entry, effect_index)
	if context.effect_key is StringName and not passive_effect_keys.has(context.effect_key):
		passive_effect_keys.append(context.effect_key)
	return context


func _build_passive_effect_key(skill_entry: SkillEntry, effect_index: int) -> StringName:
	var skill_id := skill_entry.get_skill_id()
	return StringName("passive_skill_%s_%s" % [String(skill_id), str(effect_index)])


func _build_active_source_key(skill_entry: SkillEntry) -> StringName:
	return StringName("active_skill_%s" % String(skill_entry.get_skill_id()))


func _resolve_run_stats() -> RunStats:
	var node := get_parent()
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null


func _clear_passive_effects() -> void:
	# 先让被动效果走自己的 remove，便于条件型被动断开信号、移除状态。
	for record in active_passive_effects:
		var effect := record.get("effect") as PassiveSkillEffect
		var context := record.get("context") as SkillContext
		if effect != null and context != null:
			effect.remove(context)

	active_passive_effects.clear()

	# 兜底清理旧式属性修饰器，避免某些旧被动没有正确实现 remove 时残留。
	if stats_controller != null:
		for effect_key in passive_effect_keys:
			stats_controller.clear_effect_modifiers(effect_key)

	passive_effect_keys.clear()
