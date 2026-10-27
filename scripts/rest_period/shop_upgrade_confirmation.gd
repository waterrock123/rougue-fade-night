@tool
class_name ShopUpgradeConfirmation
extends RefCounted

## 确认绑定当时的目标等级和费用，超时或价格改变后必须重新确认。
var target_level: int = -1
var cost: int = -1
var expires_at: int = 0


func begin(level: int, price: int, now_msec: int) -> void:
	target_level = level
	cost = price
	expires_at = now_msec + 4000


func is_active(now_msec: int) -> bool:
	return target_level >= 0 and now_msec < expires_at


func matches(level: int, price: int, now_msec: int) -> bool:
	return is_active(now_msec) and target_level == level and cost == price


func clear() -> void:
	target_level = -1
	cost = -1
	expires_at = 0
