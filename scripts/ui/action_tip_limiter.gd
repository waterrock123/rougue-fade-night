@tool
class_name ActionTipLimiter
extends RefCounted

## 只限制操作提示；地图奖励日志仍逐条保留。相同操作使用稳定key，避免倒计时文字绕过去重。
var last_shown: Dictionary = {}


func acquire(key: String, now_msec: int, interval_msec: int = 900) -> bool:
	if key.is_empty():
		return false
	if last_shown.has(key) and now_msec - int(last_shown[key]) < interval_msec:
		return false
	if last_shown.size() >= 128 and not last_shown.has(key):
		last_shown.erase(last_shown.keys()[0])
	last_shown[key] = now_msec
	return true
