## 地图宝罐的可配置奖励组合；权重只用于池内抽取，不影响大奖判定。
class_name MapLootReward
extends Resource

@export var reward_name: String = ""
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
@export var gold: int = 0
@export var heal: float = 0.0
@export var energy: float = 0.0
@export var random_relic: bool = false
@export var upgraded_relic: bool = false
