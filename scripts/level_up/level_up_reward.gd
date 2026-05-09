class_name LevelUpReward
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var desc: String
@export var icon: Texture2D
@export var rarity: int = 0


func apply(context: LevelUpRewardContext):
	pass


func is_available(_context: LevelUpRewardContext) -> bool:
	return true


# 奖励按钮显示用标题。默认使用手填 title，子类可以改成读取 SkillData。
func get_display_title() -> String:
	return title


# 奖励按钮显示用描述。默认使用手填 desc，子类可以改成读取 SkillData。
func get_display_desc() -> String:
	return desc


# 奖励按钮显示用图标。默认使用手填 icon，子类可以改成读取 SkillData。
func get_display_icon() -> Texture2D:
	return icon
