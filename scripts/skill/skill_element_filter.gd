## 可复用的元素筛选配置，可导出在被动、装备或技能效果资源中；本资源只负责判断。
@tool
class_name SkillElementFilter
extends Resource

## 为空不限制；常用元素：fire、ice、lightning、magic、poison。
@export var required_elements: Array[StringName] = []
## 开启时需同时具有全部要求的元素，否则有任意一个即可。
@export var require_all: bool = false
## 具有任意排除元素时拒绝，优先于required_elements。
@export var excluded_elements: Array[StringName] = []


func matches_elements(elements: Array[StringName]) -> bool:
	var excluded: Array[StringName] = SkillElementTags.normalized(excluded_elements)
	if not excluded.is_empty() and SkillElementTags.matches(elements, excluded):
		return false
	return SkillElementTags.matches(elements, required_elements, require_all)
