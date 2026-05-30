## 遗物有效售价加成。
## Relic.get_effective_sell_price() 会读取这个加成，让 tooltip、出售预览和实际出售收益保持一致。
class_name SellGoldBonusEffect
extends RelicEffect

@export var bonus_gold: int = 1


func get_sell_gold_bonus() -> int:
	return bonus_gold
