class_name RunStartup
extends Resource

enum Type { NEW_RUN, CONTINUED_RUN }

@export var type: Type = Type.NEW_RUN
@export var picked_character: Character


# 判断这份启动数据是否足以开始一局新游戏。
func can_start_new_run() -> bool:
	return type == Type.NEW_RUN and picked_character != null


# 根据角色资源创建这一局要使用的玩家构筑数据。
func create_player_build() -> PlayerBuild:
	if picked_character == null:
		return null

	var build := PlayerBuild.new()
	build.player_stats = _duplicate_resource(picked_character.start_stats)
	build.player_inventory = _duplicate_resource(picked_character.start_inventory)
	build.player_equipment = _duplicate_resource(picked_character.start_equipment)
	build.current_health = 0.0
	build.current_energy = 0.0
	_apply_start_skills(build)
	return build


# 根据角色资源创建本局要持久化的商店状态。
func create_shop() -> Shop:
	if picked_character == null:
		return null

	return _duplicate_resource(picked_character.start_shop) as Shop


# 根据角色资源创建本局使用的商店配置。
func create_shop_config() -> ShopConfig:
	if picked_character == null:
		return null

	return _duplicate_resource(picked_character.start_shop_config) as ShopConfig


func _duplicate_resource(resource: Resource):
	if resource == null:
		return null
	return resource.duplicate(true)


# 把角色资源上配置的起始技能写入本局 PlayerBuild。
# 这里同时兼容旧字段 start_skill 和新字段 start_skills。
func _apply_start_skills(build: PlayerBuild) -> void:
	if build == null or picked_character == null:
		return

	if picked_character.start_skill != null:
		build.add_start_skill_entry(_duplicate_resource(picked_character.start_skill) as SkillEntry)

	for skill_entry in picked_character.start_skills:
		if skill_entry == null:
			continue
		build.add_start_skill_entry(_duplicate_resource(skill_entry) as SkillEntry)
