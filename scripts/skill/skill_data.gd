class_name SkillData
extends Resource

@export var id: StringName
@export var skill_name: String
@export_multiline var desc: String
@export var icon: Texture2D
@export var rarity: int = 0
@export var max_level: int = 1
@export var tags: Array[StringName] = []
