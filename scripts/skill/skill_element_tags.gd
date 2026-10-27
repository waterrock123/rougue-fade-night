## 技能元素的纯数据工具。元素不等于伤害类型，也不参与UI、抗性或伤害公式。
## 使用StringName而不是封闭枚举，后续可直接增加wind等新的元素标识。
@tool
class_name SkillElementTags
extends RefCounted

const FIRE: StringName = &"fire"
const ICE: StringName = &"ice"
const LIGHTNING: StringName = &"lightning"
const MAGIC: StringName = &"magic"
const POISON: StringName = &"poison"


## 去空白、统一小写并去重；返回独立数组，不改写资源中的原数组。
static func normalized(tags: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for tag: StringName in tags:
		var key: StringName = StringName(String(tag).strip_edges().to_lower())
		if key != &"" and not result.has(key):
			result.append(key)
	return result


static func has_tag(tags: Array[StringName], tag: StringName) -> bool:
	var key: StringName = StringName(String(tag).strip_edges().to_lower())
	return key != &"" and normalized(tags).has(key)


## required为空表示没有筛选限制；否则按任一/全部匹配进行判断。
static func matches(tags: Array[StringName], required: Array[StringName], require_all: bool = false) -> bool:
	var wanted: Array[StringName] = normalized(required)
	if wanted.is_empty():
		return true
	var available: Array[StringName] = normalized(tags)
	for tag: StringName in wanted:
		if require_all and not available.has(tag):
			return false
		if not require_all and available.has(tag):
			return true
	return require_all
