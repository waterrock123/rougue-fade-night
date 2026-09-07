@tool
class_name SkillDataValidator
extends RefCounted

const SKILL_FOLDERS: Array[String] = [
	"res://activate_skill",
	"res://passive_skill",
]
const CHARACTER_FOLDER: String = "res://character_resource"
const LEVEL_UP_SCENE_PATH: String = "res://scenes/ability/level_up_controller.tscn"
const REPORT_PATH: String = "user://editor_data_validation_report.txt"

var skills: Array[SkillData] = []
var skills_by_id: Dictionary = {}
var skill_paths_by_id: Dictionary = {}
var known_character_ids: Dictionary = {}
var parent_ids_by_skill_id: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []


## 执行一次完整的编辑器数据扫描，并返回可显示的报告。
func validate_project() -> Dictionary:
	_reset_state()
	_collect_skill_resources()
	_collect_character_resources()
	_validate_skill_resources()
	_validate_skill_graph()
	_validate_level_up_reward_pool()

	var report: String = _build_report()
	_write_report(report)
	return {
		"report": report,
		"has_errors": not errors.is_empty(),
		"error_count": errors.size(),
		"warning_count": warnings.size(),
	}


func _reset_state() -> void:
	skills.clear()
	skills_by_id.clear()
	skill_paths_by_id.clear()
	known_character_ids.clear()
	parent_ids_by_skill_id.clear()
	errors.clear()
	warnings.clear()


## 递归读取技能资源。无法加载的资源直接记录为错误，方便定位损坏引用。
func _collect_skill_resources() -> void:
	var resource_paths: Array[String] = []
	for folder_path: String in SKILL_FOLDERS:
		_collect_resource_paths(folder_path, resource_paths)

	for resource_path: String in resource_paths:
		var resource: Resource = ResourceLoader.load(resource_path) as Resource
		if resource == null:
			_add_error("无法加载技能资源：%s" % resource_path)
			continue
		var skill: SkillData = resource as SkillData
		if skill == null:
			continue
		skills.append(skill)
		_register_skill(skill)


func _register_skill(skill: SkillData) -> void:
	var skill_path: String = skill.resource_path
	if _is_empty_id(skill.id):
		_add_error("技能缺少 id：%s" % skill_path)
		return

	if skills_by_id.has(skill.id):
		var old_path: String = String(skill_paths_by_id.get(skill.id, ""))
		_add_error("技能 id 重复：%s\n  - %s\n  - %s" % [String(skill.id), old_path, skill_path])
		return

	skills_by_id[skill.id] = skill
	skill_paths_by_id[skill.id] = skill_path


## 读取角色资源，收集 id、资源文件名和 Character 自己提供的匹配 id。
func _collect_character_resources() -> void:
	var resource_paths: Array[String] = []
	_collect_resource_paths(CHARACTER_FOLDER, resource_paths)

	for resource_path: String in resource_paths:
		_register_character_folder_id(resource_path)
		var resource: Resource = ResourceLoader.load(resource_path) as Resource
		if resource == null:
			_add_error("无法加载角色资源：%s" % resource_path)
			continue
		var character: Character = resource as Character
		if character == null:
			continue
		if _is_empty_id(character.id):
			_add_error("角色缺少 id：%s" % resource_path)
		for character_id: StringName in character.get_character_match_ids():
			known_character_ids[character_id] = true


## 当编辑器暂时没有识别自定义 Character 类型时，用约定的目录结构兜底。
func _register_character_folder_id(resource_path: String) -> void:
	var parent_path: String = resource_path.get_base_dir()
	var folder_id: String = parent_path.get_file()
	var file_id: String = resource_path.get_file().get_basename()
	if folder_id.is_empty() or folder_id == "character_resource":
		return
	if folder_id == file_id:
		known_character_ids[StringName(folder_id)] = true


func _collect_resource_paths(folder_path: String, result: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(folder_path)
	if directory == null:
		_add_warning("找不到扫描目录：%s" % folder_path)
		return

	directory.list_dir_begin()
	while true:
		var file_name: String = directory.get_next()
		if file_name.is_empty():
			break
		if file_name == "." or file_name == "..":
			continue

		var full_path: String = folder_path.path_join(file_name)
		if directory.current_is_dir():
			_collect_resource_paths(full_path, result)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			result.append(full_path)
	directory.list_dir_end()


## 检查技能自身字段、角色归属和每条升级边是否有效。
func _validate_skill_resources() -> void:
	for skill: SkillData in skills:
		var skill_label: String = _skill_label(skill)
		if skill.skill_name.strip_edges().is_empty():
			_add_warning("技能名称为空：%s" % skill_label)
		if skill.desc.strip_edges().is_empty():
			_add_warning("技能描述为空：%s" % skill_label)
		if skill.icon == null:
			_add_warning("技能图标为空：%s" % skill_label)

		for allowed_id: StringName in skill.allowed_character_ids:
			if not known_character_ids.has(allowed_id):
				_add_error("技能归属角色不存在：%s -> %s" % [skill_label, String(allowed_id)])

		var option_ids: Dictionary = {}
		for target: SkillData in skill.upgrade_options:
			if target == null:
				_add_error("技能包含空的升级目标：%s" % skill_label)
				continue
			if _is_empty_id(target.id):
				_add_error("技能升级目标缺少 id：%s" % skill_label)
				continue
			if option_ids.has(target.id):
				_add_error("技能存在重复的升级目标：%s -> %s" % [skill_label, String(target.id)])
			option_ids[target.id] = true
			if not skills_by_id.has(target.id):
				_add_error("技能升级目标未被扫描到：%s -> %s" % [skill_label, String(target.id)])
				continue
			var registered_target: SkillData = skills_by_id[target.id] as SkillData
			if registered_target != target:
				_add_error("技能升级目标引用了另一个同 id 资源：%s -> %s" % [skill_label, String(target.id)])
			if not target.is_upgrade_skill:
				_add_error("升级目标没有标记为升级技能：%s -> %s" % [skill_label, _skill_label(target)])


## 检查升级图是否有孤儿节点、循环或过多父节点。
func _validate_skill_graph() -> void:
	for skill: SkillData in skills:
		if _is_empty_id(skill.id):
			continue
		for target: SkillData in skill.get_upgrade_options():
			if target == null or _is_empty_id(target.id) or not skills_by_id.has(target.id):
				continue
			var parent_ids: Array = parent_ids_by_skill_id.get(target.id, []) as Array
			parent_ids.append(skill.id)
			parent_ids_by_skill_id[target.id] = parent_ids

	for skill: SkillData in skills:
		if skill.is_upgrade_skill and not parent_ids_by_skill_id.has(skill.id):
			_add_error("升级技能没有任何来源技能：%s" % _skill_label(skill))
		if skill.is_upgrade_skill and not skill.get_upgrade_options().is_empty():
			_add_warning("升级技能仍然存在下一级升级目标：%s" % _skill_label(skill))
		if parent_ids_by_skill_id.has(skill.id):
			var parent_ids: Array = parent_ids_by_skill_id[skill.id] as Array
			if parent_ids.size() > 1:
				_add_warning("技能拥有多个来源技能，技能树可能出现多分支连接：%s <- %s" % [
					_skill_label(skill),
					str(parent_ids),
				])

	var states: Dictionary = {}
	for skill: SkillData in skills:
		if _is_empty_id(skill.id):
			continue
		_visit_skill_for_cycle(skill, states, [])


func _visit_skill_for_cycle(
	skill: SkillData,
	states: Dictionary,
	path: Array[StringName]
) -> void:
	var current_state: int = int(states.get(skill.id, 0))
	if current_state == 2:
		return
	if current_state == 1:
		_add_error("技能升级关系存在循环：%s" % _format_skill_path(path, skill.id))
		return

	states[skill.id] = 1
	var next_path: Array[StringName] = []
	for path_id: StringName in path:
		next_path.append(path_id)
	next_path.append(skill.id)

	for target: SkillData in skill.get_upgrade_options():
		if target == null or _is_empty_id(target.id) or not skills_by_id.has(target.id):
			continue
		_visit_skill_for_cycle(target, states, next_path)
	states[skill.id] = 2


func _format_skill_path(path: Array[StringName], closing_id: StringName) -> String:
	var labels: Array[String] = []
	for skill_id: StringName in path:
		labels.append(String(skill_id))
	labels.append(String(closing_id))
	return " -> ".join(labels)


## 检查升级场景中嵌入的奖励池，避免奖励引用失效技能或错误技能阶段。
func _validate_level_up_reward_pool() -> void:
	var packed_scene: PackedScene = ResourceLoader.load(LEVEL_UP_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_add_error("无法加载升级场景，无法检查奖励池：%s" % LEVEL_UP_SCENE_PATH)
		return

	var controller: Node = packed_scene.instantiate()
	if controller == null:
		_add_error("无法实例化升级场景，无法检查奖励池：%s" % LEVEL_UP_SCENE_PATH)
		return

	var reward_pool: LevelUpRewardPool = controller.get("reward_pool") as LevelUpRewardPool
	if reward_pool == null:
		_add_error("升级场景没有有效的 reward_pool：%s" % LEVEL_UP_SCENE_PATH)
		controller.free()
		return

	var reward_ids: Dictionary = {}
	for reward: LevelUpReward in reward_pool.rewards:
		if reward == null:
			_add_error("升级奖励池包含空奖励")
			continue
		if _is_empty_id(reward.id):
			_add_warning("升级奖励没有填写 id：%s" % reward.resource_path)
		elif reward_ids.has(reward.id):
			_add_error("升级奖励 id 重复：%s" % String(reward.id))
		else:
			reward_ids[reward.id] = true

		var active_reward: RewardGrantActiveSkill = reward as RewardGrantActiveSkill
		if active_reward != null:
			_validate_reward_skill_reference(reward, active_reward.skill_data, "主动技能奖励")

		var passive_reward: RewardGrantPassiveSkill = reward as RewardGrantPassiveSkill
		if passive_reward != null:
			_validate_reward_skill_reference(reward, passive_reward.skill_data, "被动技能奖励")

		var upgrade_reward: RewardUpgradeSkill = reward as RewardUpgradeSkill
		if upgrade_reward != null:
			_validate_upgrade_reward(upgrade_reward)

		var stat_reward: RewardIncreaseStat = reward as RewardIncreaseStat
		if stat_reward != null and stat_reward.stat_name.strip_edges().is_empty():
			_add_error("属性提升奖励缺少 stat_name：%s" % reward.resource_path)

	controller.free()


func _validate_reward_skill_reference(
	reward: LevelUpReward,
	skill: SkillData,
	reward_type: String
) -> void:
	if skill == null:
		_add_error("%s缺少 skill_data：%s" % [reward_type, reward.resource_path])
		return
	if _is_empty_id(skill.id) or not skills_by_id.has(skill.id):
		_add_error("%s引用了不存在的技能：%s" % [reward_type, _skill_label(skill)])
		return
	if skill.is_upgrade_skill:
		_add_error("普通%s不应直接引用升级技能：%s" % [reward_type, _skill_label(skill)])


func _validate_upgrade_reward(reward: RewardUpgradeSkill) -> void:
	var target: SkillData = reward.target_skill_data
	if target == null and not _is_empty_id(reward.target_skill_id):
		target = skills_by_id.get(reward.target_skill_id) as SkillData
	if target == null:
		_add_error("技能升级奖励缺少有效目标技能：%s" % reward.resource_path)
		return
	if _is_empty_id(target.id) or not skills_by_id.has(target.id):
		_add_error("技能升级奖励目标不存在：%s" % _skill_label(target))
	elif not target.is_upgrade_skill:
		_add_error("技能升级奖励目标不是升级技能：%s" % _skill_label(target))

	var source_id: StringName = reward.source_skill_id
	if _is_empty_id(source_id):
		source_id = reward.target_skill_id
	if _is_empty_id(source_id):
		_add_error("技能升级奖励缺少来源技能：%s" % reward.resource_path)
		return

	var source: SkillData = reward.source_skill_data
	if source == null:
		source = skills_by_id.get(source_id) as SkillData
	if source == null:
		_add_error("技能升级奖励来源不存在：%s" % String(source_id))
		return
	if target != null and not source.can_upgrade_to(target):
		_add_error("技能升级奖励的来源与目标没有升级关系：%s -> %s" % [
			_skill_label(source),
			_skill_label(target),
		])


func _skill_label(skill: SkillData) -> String:
	if skill == null:
		return "<空技能>"
	var skill_name: String = skill.skill_name.strip_edges()
	if skill_name.is_empty():
		return String(skill.id)
	return "%s(%s)" % [skill_name, String(skill.id)]


func _is_empty_id(value: StringName) -> bool:
	return String(value).strip_edges().is_empty()


func _add_error(message: String) -> void:
	errors.append(message)


func _add_warning(message: String) -> void:
	warnings.append(message)


func _build_report() -> String:
	var lines: Array[String] = []
	lines.append("技能与奖励数据校验报告")
	lines.append("========================")
	lines.append("技能数量：%d" % skills.size())
	lines.append("已识别角色 id：%d" % known_character_ids.size())
	lines.append("错误：%d，警告：%d" % [errors.size(), warnings.size()])
	lines.append("")

	if errors.is_empty():
		lines.append("[通过] 没有发现阻断性错误。")
	else:
		lines.append("[错误]")
		for message: String in errors:
			lines.append("- " + message)
		lines.append("")

	if warnings.is_empty():
		lines.append("[提示] 没有警告。")
	else:
		lines.append("[警告]")
		for message: String in warnings:
			lines.append("- " + message)

	return "\n".join(lines)


func _write_report(report: String) -> void:
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		_add_warning("无法写入校验报告：%s" % REPORT_PATH)
		return
	report_file.store_string(report)
