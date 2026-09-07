class_name SkillData
extends Resource

@export var id: StringName
@export var skill_name: String
@export_multiline var desc: String
@export var icon: Texture2D
@export var rarity: int = 0
@export var max_level: int = 1
@export var tags: Array[StringName] = []
## 高级技能不会直接从普通随机池出现，只能通过其来源技能升级获得。
@export var is_upgrade_skill: bool = false

## 技能升级分支。空数组表示该技能已经是最终阶段。
## 一个基础技能可以指向多个高级技能，从而形成分支升级。
@export var upgrade_options: Array[SkillData] = []

@export_group("归属")
# 为空表示通用技能；填写角色 id 后，只有对应角色能在升级奖励中随机到。
@export var allowed_character_ids: Array[StringName] = []


# 判断此技能是否允许给当前角色随机到；角色 id、资源文件名、中文名都会参与兜底匹配。
func is_available_for_character(character: Character) -> bool:
	if allowed_character_ids.is_empty():
		return true
	if character == null:
		return false

	for character_id in character.get_character_match_ids():
		if allowed_character_ids.has(character_id):
			return true

	return false


func has_upgrade_options() -> bool:
	return not get_upgrade_options().is_empty()


func get_upgrade_options() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for option: SkillData in upgrade_options:
		if option != null:
			result.append(option)
	return result


func can_upgrade_to(target_skill: SkillData) -> bool:
	if target_skill == null:
		return false
	for option: SkillData in upgrade_options:
		if option == target_skill or (option != null and option.id == target_skill.id):
			return true
	return false
