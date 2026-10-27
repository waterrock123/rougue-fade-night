class_name TutorialBuildFactory
extends RefCounted


## 起始数据深复制后才清理装备与非基础技能；不应用局外信物、不消费仓库、不写正式存档。
static func create_build(startup: RunStartup, lesson: TutorialCharacterLesson) -> PlayerBuild:
	var build: PlayerBuild = startup.create_player_build()
	if build == null:
		return null
	if build.player_inventory != null:
		_clear_slots(build.player_inventory.slots)
	if build.player_equipment != null:
		_clear_slots(build.player_equipment.equip_slots)
	var basic_id: StringName = _initial_basic_id(startup.picked_character)
	for index: int in range(build.owned_active_skills.size() - 1, -1, -1):
		var entry: SkillEntry = build.owned_active_skills[index]
		var data: ActiveSkillData = entry.skill_data as ActiveSkillData if entry != null else null
		if data == null or data.id != basic_id:
			build.owned_active_skills.remove_at(index)
		else:
			# 兼容角色资源里未勾选基础攻击标记的旧起始技能；只修正教学副本。
			data.is_basic_attack = true
	build.owned_passive_skills.clear()
	if build.player_stats != null:
		build.player_stats.base_max_energy = maxf(build.player_stats.base_max_energy, 50.0)
	if lesson != null and lesson.aim_skill != null:
		build.grant_active_skill(lesson.aim_skill.duplicate(true) as ActiveSkillData)
	build.normalize_active_skill_loadout()
	return build


static func _clear_slots(slots: Array) -> void:
	for slot: Slot in slots:
		if slot != null:
			slot.item = null


static func _initial_basic_id(character: Character) -> StringName:
	if character == null:
		return &""
	if character.start_skill != null and character.start_skill.skill_data is ActiveSkillData:
		return character.start_skill.skill_data.id
	for entry: SkillEntry in character.start_skills:
		if entry != null and entry.skill_data is ActiveSkillData and (entry.skill_data as ActiveSkillData).is_basic_attack:
			return entry.skill_data.id
	return &""
