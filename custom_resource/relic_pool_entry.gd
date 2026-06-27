class_name RelicPoolEntry
extends Resource

## 单个遗物在 RelicPool 里的配置项。
## 需要特殊权重或特殊出现区间时使用它；普通遗物可以直接放到 RelicPool.relics 里。
@export var relic: Relic
@export var weight: float = 1.0
@export var enabled: bool = true
@export var min_shop_level: int = 1
@export var max_shop_level: int = 999


func can_roll_up_to_shop_level(shop_level: int) -> bool:
	if not _is_basic_valid():
		return false
	if shop_level < min_shop_level or shop_level > max_shop_level:
		return false
	return relic.level <= shop_level


func can_roll_at_relic_level(relic_level: int) -> bool:
	if not _is_basic_valid():
		return false
	if relic_level < min_shop_level or relic_level > max_shop_level:
		return false
	return relic.level == relic_level


func _is_basic_valid() -> bool:
	return enabled and relic != null and weight > 0.0
