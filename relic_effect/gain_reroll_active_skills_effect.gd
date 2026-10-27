## 获得/升级时重随机永久主动技能，保留携带状态、栏位及初始/升级阶段。
## 基础攻击和临时装备技能不动；候选遵守角色归属、不重复，候选不足时保留原技能。
class_name GainRerollActiveSkillsEffect
extends RelicEffect

@export_dir var skill_folder: String = "res://activate_skill"
@export var respect_character_ownership: bool = true
@export var preserve_upgrade_stage: bool = true
@export var once_key: StringName = &"reroll_active_skills"

static var cached_catalogs: Dictionary = {}


func on_gain(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func on_added(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func on_upgrade(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func _apply_once(context: RelicContext) -> void:
	var run: Run = RelicGainRuntimeHelper.get_run(context)
	if run == null or run.run_stats == null or run.run_stats.player_build == null:
		return
	if not RelicGainRuntimeHelper.claim_once(context, once_key):
		return
	var build: PlayerBuild = run.run_stats.player_build
	var catalog: Array[ActiveSkillData] = get_catalog()
	reroll(build, run.run_stats.picked_character, catalog)
	# 不在拾取/碰撞回调中删除旧Ability节点；所有场景和UI共用已有携带变更信号。
	EventBus.skill_loadout_changed.emit.call_deferred()
	run.save_current_run.call_deferred()


func get_catalog() -> Array[ActiveSkillData]:
	var result: Array[ActiveSkillData] = []
	if not cached_catalogs.has(skill_folder):
		_collect_skills(skill_folder, result, {})
		cached_catalogs[skill_folder] = result
	else:
		result.assign(cached_catalogs[skill_folder])
	return result


func _collect_skills(folder: String, result: Array[ActiveSkillData], seen: Dictionary) -> void:
	var paths: PackedStringArray = DirAccess.get_files_at(folder)
	paths.sort()
	for file: String in paths:
		var filename: String = file.trim_suffix(".remap")
		if filename.get_extension() not in ["tres", "res"]:
			continue
		var skill: ActiveSkillData = load(folder.path_join(filename)) as ActiveSkillData
		if skill != null:
			_collect_skill_branches(skill, result, seen)
	var directories: PackedStringArray = DirAccess.get_directories_at(folder)
	directories.sort()
	for directory: String in directories:
		_collect_skills(folder.path_join(directory), result, seen)


func _collect_skill_branches(skill: ActiveSkillData, result: Array[ActiveSkillData], seen: Dictionary) -> void:
	if skill == null or skill.id == &"" or seen.has(skill.id):
		return
	seen[skill.id] = true
	result.append(skill)
	for branch: SkillData in skill.get_upgrade_options():
		if branch is ActiveSkillData:
			_collect_skill_branches(branch as ActiveSkillData, result, seen)


func reroll(build: PlayerBuild, character: Character, catalog: Array[ActiveSkillData]) -> void:
	var entries: Array[SkillEntry] = []
	var reserved: Dictionary = {}
	for entry: SkillEntry in build.owned_active_skills:
		if entry == null:
			continue
		var skill: ActiveSkillData = entry.skill_data as ActiveSkillData
		if not entry.is_temporary and _can_randomize(skill):
			entries.append(entry)
		else:
			reserved[entry.get_skill_id()] = true
	var pool: Array[ActiveSkillData] = []
	var seen: Dictionary = reserved.duplicate()
	for skill: ActiveSkillData in catalog:
		if _can_randomize(skill) and not seen.has(skill.id) and (not respect_character_ownership or skill.is_available_for_character(character)):
			seen[skill.id] = true
			pool.append(skill)
	# 原技能可作为候选不足的保底，即使归属规则后来变化也不删掉玩家的原技能。
	for entry: SkillEntry in entries:
		if not seen.has(entry.get_skill_id()):
			seen[entry.get_skill_id()] = true
			pool.append(entry.skill_data as ActiveSkillData)
	RunRng.shuffle_array(pool)
	var assignments: Dictionary = _make_assignments(entries, pool, character)
	for skill_index: int in assignments:
		var entry_index: int = int(assignments[skill_index])
		entries[entry_index].skill_data = pool[skill_index]
		entries[entry_index].level = 1
	build.normalize_active_skill_loadout()


func _can_randomize(skill: ActiveSkillData) -> bool:
	return skill != null and skill.ability_scene != null and skill.id != &"" and not skill.is_basic_attack and skill.id != &"101" and skill.slot_type != &"equipment" and not skill.tags.has(&"equipment_skill")


## 先为每个栏位匹配不同技能，再对缺少候选的栏位允许原技能保底；避免贪心抽取造成重复或漏栏位。
func _make_assignments(entries: Array[SkillEntry], pool: Array[ActiveSkillData], character: Character) -> Dictionary:
	var assignments: Dictionary = {}
	for entry_index: int in range(entries.size()):
		_try_assign(entry_index, entries, pool, character, assignments, {}, false)
	for entry_index: int in range(entries.size()):
		if not assignments.values().has(entry_index):
			_try_assign(entry_index, entries, pool, character, assignments, {}, true)
	return assignments


func _try_assign(index: int, entries: Array[SkillEntry], pool: Array[ActiveSkillData], character: Character, assignments: Dictionary, visited: Dictionary, allow_original: bool) -> bool:
	var original: ActiveSkillData = entries[index].skill_data as ActiveSkillData
	# 原技能放到最后尝试，尽量只在无可替代候选时保留原样。
	for pass_index: int in range(2 if allow_original else 1):
		for skill_index: int in range(pool.size()):
			var candidate: ActiveSkillData = pool[skill_index]
			var is_original: bool = candidate.id == original.id
			if visited.has(skill_index) or is_original != (pass_index == 1):
				continue
			if not is_original and respect_character_ownership and not candidate.is_available_for_character(character):
				continue
			if preserve_upgrade_stage and candidate.is_upgrade_skill != original.is_upgrade_skill:
				continue
			visited[skill_index] = true
			if not assignments.has(skill_index) or _try_assign(int(assignments[skill_index]), entries, pool, character, assignments, visited, allow_original):
				assignments[skill_index] = index
				return true
	return false
