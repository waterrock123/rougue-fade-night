class_name SkillEntry
extends Resource

@export var skill_data: SkillData
@export var level: int = 1
@export var is_equipped: bool = true
@export var slot_index: int = -1
## 临时技能通常由装备、状态或事件提供，不应被保存为玩家永久拥有的技能。
@export var is_temporary: bool = false
@export var temporary_source_key: StringName = &""


func get_skill_id() -> StringName:
	if skill_data == null:
		return &""
	return skill_data.id


func can_level_up() -> bool:
	return skill_data != null and level < skill_data.max_level


func level_up() -> void:
	if can_level_up():
		level += 1
