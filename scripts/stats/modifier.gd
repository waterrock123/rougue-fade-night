class_name Modifier
extends RefCounted

enum ModifierType {
	FLAT,
	PERCENT,
}

var stat: StringName
var modifier_type: ModifierType
var value: float
var source: Variant
var duration: float


# 构造一条属性修饰器数据。
# duration < 0 表示永久，duration > 0 表示限时。
func _init(
	stat_name: StringName = &"",
	type: ModifierType = ModifierType.FLAT,
	amount: float = 0.0,
	modifier_source: Variant = null,
	modifier_duration: float = -1.0
) -> void:
	stat = stat_name
	modifier_type = type
	value = amount
	source = modifier_source
	duration = modifier_duration


# 快速创建一个固定值修饰器。
static func create_flat(
	stat_name: StringName,
	amount: float,
	modifier_source: Variant = null,
	modifier_duration: float = -1.0
) -> Modifier:
	return Modifier.new(stat_name, ModifierType.FLAT, amount, modifier_source, modifier_duration)


# 快速创建一个百分比修饰器。
static func create_percent(
	stat_name: StringName,
	ratio: float,
	modifier_source: Variant = null,
	modifier_duration: float = -1.0
) -> Modifier:
	return Modifier.new(stat_name, ModifierType.PERCENT, ratio, modifier_source, modifier_duration)


# 判断当前修饰器是否为限时修饰器。
func is_temporary() -> bool:
	return duration > 0.0


# 判断当前修饰器是否仍然生效。
func is_active() -> bool:
	return duration != 0.0


# 推进一次修饰器持续时间。
# 返回 true 表示它在这次更新后刚好失效。
func tick(delta: float) -> bool:
	if not is_temporary():
		return false

	duration = max(duration - delta, 0.0)
	return duration == 0.0
