class_name PlayerBuild
extends Resource

# 玩家构筑数据。
# 这份资源用于在战斗场景和修整期之间共享玩家当前的属性、背包、装备和技能状态。
@export var player_stats: StatsData
@export var player_inventory: Inventory
@export var player_equipment: Equipment
@export var current_health: float = 0.0
@export var current_energy: float = 0.0

@export_group("技能构筑")
@export var active_skill_slot_limit: int = 4
@export var owned_active_skills: Array[SkillEntry] = []
@export var owned_passive_skills: Array[SkillEntry] = []


# 添加角色起始技能条目；根据 SkillData 类型自动放进主动或被动列表。
func add_start_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	if skill_entry == null or skill_entry.skill_data == null:
		return null

	if skill_entry.skill_data is ActiveSkillData:
		return _add_active_skill_entry(skill_entry)
	if skill_entry.skill_data is PassiveSkillData:
		return _add_passive_skill_entry(skill_entry)

	push_warning("PlayerBuild 收到未知类型的起始技能：%s" % String(skill_entry.get_skill_id()))
	return null


# 添加一个主动技能条目；如果已经拥有，则只负责升级。
func grant_active_skill(skill_data: ActiveSkillData) -> SkillEntry:
	if skill_data == null:
		return null

	var existing := find_active_skill_entry(skill_data.id)
	if existing != null:
		existing.level_up()
		return existing

	var entry := SkillEntry.new()
	entry.skill_data = skill_data
	entry.slot_index = owned_active_skills.size()
	owned_active_skills.append(entry)
	return entry


# 添加一个被动技能条目；如果已经拥有，则只负责升级。
func grant_passive_skill(skill_data: PassiveSkillData) -> SkillEntry:
	if skill_data == null:
		return null

	var existing := find_passive_skill_entry(skill_data.id)
	if existing != null:
		existing.level_up()
		return existing

	var entry := SkillEntry.new()
	entry.skill_data = skill_data
	owned_passive_skills.append(entry)
	return entry


# 直接添加已经配置好的主动技能条目，保留它在资源里设置的等级和装备状态。
func _add_active_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	var skill_data := skill_entry.skill_data as ActiveSkillData
	if skill_data == null:
		return null

	var existing := find_active_skill_entry(skill_data.id)
	if existing != null:
		existing.level = max(existing.level, skill_entry.level)
		existing.is_equipped = existing.is_equipped or skill_entry.is_equipped
		return existing

	skill_entry.slot_index = owned_active_skills.size()
	owned_active_skills.append(skill_entry)
	return skill_entry


# 直接添加已经配置好的被动技能条目，保留它在资源里设置的等级和装备状态。
func _add_passive_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	var skill_data := skill_entry.skill_data as PassiveSkillData
	if skill_data == null:
		return null

	var existing := find_passive_skill_entry(skill_data.id)
	if existing != null:
		existing.level = max(existing.level, skill_entry.level)
		return existing

	owned_passive_skills.append(skill_entry)
	return skill_entry


func find_active_skill_entry(skill_id: StringName) -> SkillEntry:
	return _find_skill_entry(owned_active_skills, skill_id)


func find_passive_skill_entry(skill_id: StringName) -> SkillEntry:
	return _find_skill_entry(owned_passive_skills, skill_id)


func _find_skill_entry(entries: Array[SkillEntry], skill_id: StringName) -> SkillEntry:
	for entry in entries:
		if entry != null and entry.get_skill_id() == skill_id:
			return entry

	return null
