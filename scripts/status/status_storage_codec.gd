class_name StatusStorageCodec
extends RefCounted

## 只保存状态资源的导出配置，不序列化节点、信号、计时器或已释放的施法者。
## 内嵌效果也写入存档，支持动态生成且没有 .tres 路径的临时属性状态。
static func encode_resource(resource: Resource) -> Dictionary:
	if resource == null:
		return {}
	if not (resource is StatusData or resource is StatusEffect):
		return {"path": resource.resource_path} if resource.resource_path.begins_with("res://") else {}
	var script: Script = resource.get_script() as Script
	var properties: Dictionary = {}
	for property: Dictionary in script.get_script_property_list():
		var usage: int = int(property.usage)
		if usage & PROPERTY_USAGE_STORAGE:
			properties[str(property.name)] = _encode_value(resource.get(property.name))
	return {"script": script.resource_path, "properties": properties}


static func _encode_value(value: Variant) -> Dictionary:
	if value is Resource:
		return {"resource": encode_resource(value as Resource)}
	if value is Array:
		var items: Array = []
		for entry: Variant in value:
			items.append(_encode_value(entry))
		return {"array": items}
	if value is Dictionary:
		var entries: Array = []
		for key: Variant in value:
			entries.append([_encode_value(key), _encode_value(value[key])])
		return {"dictionary": entries}
	# str_to_var 不允许对象构造；保留 Color、StringName、整数和向量等原有类型。
	return {"value": var_to_str(value)} if not (value is Object) else {"value": "null"}


static func decode_resource(data: Dictionary) -> Resource:
	var path: String = str(data.get("path", ""))
	if path.begins_with("res://") and ".." not in path and path.get_extension() != "gd":
		return load(path) as Resource if ResourceLoader.exists(path) else null
	var script_path: String = str(data.get("script", ""))
	if not script_path.begins_with("res://scripts/status/") or ".." in script_path or not ResourceLoader.exists(script_path):
		return null
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return null
	var resource: Resource = script.new() as Resource
	if not (resource is StatusData or resource is StatusEffect):
		return null
	var properties: Dictionary = data.get("properties", {})
	for property: Dictionary in script.get_script_property_list():
		var name: String = str(property.name)
		if properties.has(name) and int(property.usage) & PROPERTY_USAGE_STORAGE:
			_set_property(resource, name, _decode_value(properties[name]))
	return resource


static func _set_property(resource: Resource, name: String, value: Variant) -> void:
	var original: Variant = resource.get(name)
	if original is Array and value is Array:
		# 保留原导出数组的元素类型，避免 Array 与 Array[StatusEffect] 赋值报错。
		var typed_values: Array = original.duplicate()
		typed_values.assign(value)
		resource.set(name, typed_values)
	else:
		resource.set(name, value)


static func _decode_value(data: Dictionary) -> Variant:
	if data.has("resource"):
		return decode_resource(data.resource)
	if data.has("array"):
		var result: Array = []
		for entry: Dictionary in data.array:
			result.append(_decode_value(entry))
		return result
	if data.has("dictionary"):
		var result: Dictionary = {}
		for entry: Array in data.dictionary:
			result[_decode_value(entry[0])] = _decode_value(entry[1])
		return result
	return str_to_var(str(data.get("value", "null")))


static func capture(instance: StatusInstance) -> Dictionary:
	if instance == null or instance.status_data == null or instance.remaining_duration <= 0.0:
		return {}
	var effect_states: Array[Dictionary] = []
	for effect: StatusEffect in instance.status_data.effects:
		effect_states.append(effect.capture_storage_state(instance) if effect != null else {})
	return {"data": encode_resource(_capture_effective_data(instance)), "stacks": instance.stacks, "duration": instance.remaining_duration, "effect_states": effect_states}


## 狼奶可能已把正向属性转为战斗/永久收益；只存当前仍由状态实际提供的部分，防止取回重复加成。
static func _capture_effective_data(instance: StatusInstance) -> StatusData:
	var data: StatusData = instance.status_data.duplicate(true) as StatusData
	var stats: StatsController = instance.controller.get_stats_controller() if is_instance_valid(instance.controller) else null
	if stats == null:
		return data
	for index: int in range(data.effects.size()):
		if not (data.effects[index] is StatusAddStatEffect or data.effects[index] is StatusAddStatsEffect):
			continue
		var key: String = instance.get_effect_key(index)
		if not stats.effect_modifiers.has(key):
			continue
		var effect: StatusAddStatsEffect = StatusAddStatsEffect.new()
		for modifier: Modifier in stats.effect_modifiers[key]:
			effect.modifier_type = modifier.modifier_type
			effect.stat_values[modifier.stat] = modifier.value / float(maxi(instance.stacks, 1))
		data.effects[index] = effect
	return data
