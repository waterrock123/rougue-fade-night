class_name TutorialCharacterLesson
extends Resource

## 只配置教学差异，不改变角色的正式起始技能或技能归属。
@export var character_id: StringName
@export var aim_skill: ActiveSkillData
@export_multiline var basic_hint: String = "把鼠标指向假人，使用基础攻击命中它。"
@export_multiline var aim_hint: String = "按住技能键观察指示区域，移动鼠标瞄准假人，然后松开释放。"


func matches(character: Character) -> bool:
	return character != null and character.id == character_id
