class_name TagEffect
extends Resource

enum CountSource {
	EQUIPMENT_ONLY,
	INVENTORY_AND_EQUIPMENT,
}

@export_group("基础信息")
@export var id: StringName
@export var tag: RelicTag
@export var effect_name: String
@export var icon: Texture2D
@export_multiline var desc: String

@export_group("触发条件")
@export var required_count: int = 3
## 默认只统计装备栏；少数特殊 tag 可以改成背包和装备栏都统计。
@export var count_source: CountSource = CountSource.EQUIPMENT_ONLY
## 一次性效果触发后会记录到 RunStats，不会因为重新计算 tag 而再次触发。
@export var is_once: bool = false


func can_activate(context: TagEffectContext) -> bool:
	if context == null:
		return false
	if required_count <= 0:
		return false
	if context.tag_count < required_count:
		return false
	if is_once and context.is_once_completed():
		return false
	return true


func on_activate(_context: TagEffectContext) -> void:
	pass


func on_deactivate(_context: TagEffectContext) -> void:
	pass


func get_display_name() -> String:
	if not effect_name.is_empty():
		return effect_name
	return String(id)


func get_tag_key() -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name
