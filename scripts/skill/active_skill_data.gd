class_name ActiveSkillData
extends SkillData

@export var ability_scene: PackedScene
@export var base_cooldown: float = 0.0
@export var base_energy_cost: float = 0.0
@export var slot_type: StringName
## 基础攻击始终占据第一个技能栏，不能被玩家卸下，也不计入主动技能上限。
@export var is_basic_attack: bool = false

@export_group("技能元素（隐藏）")
## 技能本身的元素身份，允许多个；与普通tags、伤害类型独立，不自动显示到UI。
## 常用：fire(火)、ice(冰)、lightning(雷)、magic(魔力)、poison(毒)。空数组表示无元素。
@export var element_tags: Array[StringName] = []


func get_element_tags() -> Array[StringName]:
	return SkillElementTags.normalized(element_tags)


func has_element_tag(tag: StringName) -> bool:
	return SkillElementTags.has_tag(element_tags, tag)


func matches_element_tags(required: Array[StringName], require_all: bool = false) -> bool:
	return SkillElementTags.matches(element_tags, required, require_all)
