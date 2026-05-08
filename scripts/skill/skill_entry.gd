class_name SkillEntry
extends Resource

@export var skill_data: SkillData
@export var level: int = 1
@export var is_equipped: bool = true
@export var slot_index: int = -1


func get_skill_id() -> StringName:
	if skill_data == null:
		return &""
	return skill_data.id


func can_level_up() -> bool:
	return skill_data != null and level < skill_data.max_level


func level_up() -> void:
	if can_level_up():
		level += 1
