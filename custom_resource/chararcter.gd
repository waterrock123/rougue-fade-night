class_name Character
extends Resource

# 角色稳定标识，用于技能归属、存档和后续局外配置；资源名会作为未填写时的兜底。
@export var id: StringName

@export_group("视觉资源")
@export var character_name:String
@export_multiline var description: String
@export var background:Texture
## 角色的逐帧动画、默认朝向和视觉偏移等配置。
@export var visual_data: CharacterVisualData


@export_group("游戏资源")
@export var start_stats:StatsData
# 兼容旧配置：如果只配置一个起始技能，也会在开局时加入玩家构筑。
@export var start_skill:SkillEntry
# 新配置：角色可以拥有多个起始技能，主动/被动会在创建 PlayerBuild 时自动分流。
@export var start_skills:Array[SkillEntry] = []
@export var start_inventory:Inventory
@export var start_equipment:Equipment
@export var start_shop:Shop
@export var start_shop_config:ShopConfig
@export var shop_keeper_pool:Array[ShopKeeper]
@export var main_attributes: Array[StringName] = []


# 返回角色用于规则匹配的全部候选标识，兼容旧资源未填写 id 的情况。
func get_character_match_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	_append_match_id(result, id)
	_append_match_id(result, StringName(_get_resource_file_name()))
	_append_match_id(result, StringName(character_name))
	return result


# 获取优先级最高的角色标识；外部系统只需要一个 id 时使用它。
func get_character_id() -> StringName:
	if id != &"":
		return id
	var file_name := _get_resource_file_name()
	if not file_name.is_empty():
		return StringName(file_name)
	return StringName(character_name)


func _append_match_id(result: Array[StringName], value: StringName) -> void:
	if value == &"" or result.has(value):
		return
	result.append(value)


func _get_resource_file_name() -> String:
	if resource_path.is_empty():
		return ""
	return resource_path.get_file().get_basename()
