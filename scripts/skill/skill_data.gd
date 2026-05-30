class_name SkillData
extends Resource

@export var id: StringName
@export var skill_name: String
@export_multiline var desc: String
@export var icon: Texture2D
@export var rarity: int = 0
@export var max_level: int = 1
@export var tags: Array[StringName] = []

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
