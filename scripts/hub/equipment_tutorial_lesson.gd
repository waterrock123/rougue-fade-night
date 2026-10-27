class_name EquipmentTutorialLesson
extends Resource

## 教学装备与观察属性按角色配置，正式遗物资源不做任何改写。
@export var character_id: StringName
@export var relic: Relic
@export var stat_key: StringName = &"strength"
@export var stat_name: String = "力量"
@export var stat_increase: float = 1.0
