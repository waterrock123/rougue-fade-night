class_name Stats
extends Resource

# 玩家或实体的基础属性资源。
# 这个脚本只负责存储数据，不负责运行时计算。

@export_group("Meta")
@export var entity_name: String = ""

@export_group("Base Stats")
@export var base_max_health: float = 0.0
@export var base_max_energy: float = 0.0
@export var base_energy_regen_tick_value: float = 3.0
@export var base_damage_reduction_rate: float = 0.0
@export var base_static_damage_reduction: int = 0
@export var base_dodge_rate: float = 0.0
@export var base_crit_chance: float = 0.05
@export var base_crit_damage: float = 1.5
@export var base_cooldown_reduction: float = 0.0
@export var base_move_speed: float = 100.0

@export_group("Primary Stats")
@export var strength: int = 5
@export var dexterity: int = 5
@export var intelligence: int = 5
@export var constitution: int = 5
@export var speed: int = 5
@export var charm: int = 5
@export var luck: int = 5
