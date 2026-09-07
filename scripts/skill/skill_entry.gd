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
	# 保留旧接口，避免旧脚本报错；新的升级判断改为是否存在升级分支。
	return skill_data != null and skill_data.has_upgrade_options()


func level_up() -> void:
	# 旧的数字等级不再驱动技能升级，真正的升级由 evolve_to 完成。
	pass


func can_evolve_to(target_skill: SkillData) -> bool:
	return skill_data != null and skill_data.can_upgrade_to(target_skill)


func evolve_to(target_skill: SkillData) -> bool:
	if not can_evolve_to(target_skill):
		return false

	skill_data = target_skill
	# level 仅为旧存档兼容字段，统一保持为 1。
	level = 1
	return true
