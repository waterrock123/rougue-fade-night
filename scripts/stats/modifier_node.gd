class_name ModifierNode
extends Node

@export var stat: StringName = &"max_health"
@export_enum("flat", "percent") var type: String = "flat"
@export var value: float = 0.0
@export var source: String = ""
@export var duration: float = -1.0
@export var enabled: bool = true


# 把场景中的节点配置转换成运行时 Modifier 数据对象。
func build_modifier() -> Modifier:
	var modifier_type := Modifier.ModifierType.FLAT
	if type == "percent":
		modifier_type = Modifier.ModifierType.PERCENT

	return Modifier.new(stat, modifier_type, value, source, duration)


# 判断这个节点修饰器当前是否参与属性计算。
func is_modifier_enabled() -> bool:
	return enabled
