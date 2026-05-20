class_name Ability
extends Node

# 技能身份与展示信息由 ActiveSkillData 注入，避免 Ability 场景和 SkillData 重复维护同一份文本。
var id:StringName
var ability_name:String
var icon_texture: Texture2D
@export var cooldown: float =2.0
@export var energy_cost:float = 10.0
var desc:String
var skill_data: ActiveSkillData
var skill_entry: SkillEntry
var runtime_slot_index: int = -1


var current_cooldown: float
var can_be_casted = false
var preview_context: AbilityContext


# 主动技能运行时注册后调用，把资源里的数据同步到 Ability 实例。
func apply_skill_data(new_skill_data: ActiveSkillData, new_skill_entry: SkillEntry = null) -> void:
	skill_data = new_skill_data
	skill_entry = new_skill_entry
	if skill_data == null:
		return

	id = skill_data.id
	ability_name = skill_data.skill_name
	icon_texture = skill_data.icon
	desc = skill_data.desc
	if skill_data.base_cooldown > 0.0:
		cooldown = skill_data.base_cooldown
	if skill_data.base_energy_cost > 0.0:
		energy_cost = skill_data.base_energy_cost


func  activate(entity: Entity):
	var context=AbilityContext.new(entity,self)
	
	_activate_components(context)


func has_cast_preview() -> bool:
	for child in get_children():
		if child is AbilityComponent and child.has_method("begin_preview"):
			return true
	return false


# 按住技能键时调用，只启动“显示范围”等预览组件，不触发真正的技能效果。
func begin_cast_preview(entity: Entity) -> void:
	if not has_cast_preview():
		return

	preview_context = AbilityContext.new(entity, self)
	for child in get_children():
		if child is AbilityComponent and child.has_method("begin_preview"):
			child.begin_preview(preview_context)


# 松开技能键或取消施法时调用，让所有预览组件收尾隐藏。
func end_cast_preview() -> void:
	for child in get_children():
		if child is AbilityComponent and child.has_method("end_preview"):
			child.end_preview()
	preview_context = null

func _activate_components(context: AbilityContext):
	for child in get_children():
		if child is AbilityComponent and child.auto_activate:	
			child.activate(context)


# 供动画关键帧或其他控制组件按名字手动触发指定技能组件。
func trigger_component_by_name(component_name: String, context: AbilityContext) -> void:
	var component := get_node_or_null(component_name)
	if component is AbilityComponent:
		(component as AbilityComponent).activate(context)
