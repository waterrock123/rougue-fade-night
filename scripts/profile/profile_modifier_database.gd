class_name ProfileModifierDatabase
extends Resource

## 集中登记可被事件解锁的局外修正器。
@export var modifiers: Array[ProfileModifierData] = []


func find_modifier(modifier_id: StringName) -> ProfileModifierData:
	for modifier_data: ProfileModifierData in modifiers:
		if modifier_data != null and modifier_data.modifier_id == modifier_id:
			return modifier_data
	return null


## 将可携带的信物筛选集中到数据库，避免 UI 与档案管理器重复判断类型。
func get_equippable_tokens(unlocked_modifier_ids: Array[StringName]) -> Array[ProfileModifierData]:
	var result: Array[ProfileModifierData] = []
	for modifier_data: ProfileModifierData in modifiers:
		if modifier_data == null:
			continue
		if modifier_data.activation_mode != ProfileModifierData.ActivationMode.EQUIPPABLE_TOKEN:
			continue
		if unlocked_modifier_ids.has(modifier_data.modifier_id):
			result.append(modifier_data)
	return result
