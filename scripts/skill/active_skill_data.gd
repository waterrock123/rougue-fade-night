class_name ActiveSkillData
extends SkillData

@export var ability_scene: PackedScene
@export var base_cooldown: float = 0.0
@export var base_energy_cost: float = 0.0
@export var slot_type: StringName
## 基础攻击始终占据第一个技能栏，不能被玩家卸下，也不计入主动技能上限。
@export var is_basic_attack: bool = false
