class_name StatsData
extends Resource

# 通用实体的初始化属性资源。
# 它只负责存“初始数据”，不参与运行时状态计算。

enum StatType {
	MAX_HEALTH,
	MAX_ENERGY,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	MOVE_SPEED,
	STRENGTH,
	DEXTERITY,
	INTELLIGENCE,
	CONSTITUTION,
	SPEED,
	CHARM,
	LUCK,
	POISE_DAMAGE_MULTIPLIER,
}

@export_group("Meta")
@export var entity_name: String = ""

@export_group("Base Stats")
@export var base_max_health: float = 0.0
@export var base_max_energy: float = 0.0
@export var base_energy_regen_tick_value: float = 0.0
@export var base_damage_reduction_rate: float = 0.0
@export var base_static_damage_reduction: int = 0
@export var base_dodge_rate: float = 0.0
@export var base_crit_chance: float = 0.05
@export var base_crit_damage: float = 1.5
@export var base_cooldown_reduction: float = 0.0
@export var base_move_speed: float = 0.0
## 攻击造成的削韧倍率。1.0 表示保持技能原始削韧值。
@export var base_poise_damage_multiplier: float = 1.0

@export_group("Primary Stats")
@export var strength: int = 0
@export var dexterity: int = 0
@export var intelligence: int = 0
@export var constitution: int = 0
@export var speed: int = 0
@export var charm: int = 0
@export var luck: int = 0
