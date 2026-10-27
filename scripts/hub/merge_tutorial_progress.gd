@tool
class_name MergeTutorialProgress
extends RefCounted

## 合成信号通常早于购买完成信号；两项都验证后才推进，兼容不同信号顺序。
signal stage_changed(stage: int)
signal completed()
enum Stage { BUY, OBSERVE, CHOOSE, RESTORED, COMPLETE }
var stage: Stage = Stage.BUY
var purchased: bool = false
var merged: bool = false


func record_purchase(valid: bool) -> void:
	if stage == Stage.BUY and valid:
		purchased = true
		_try_advance_purchase()


func record_merge(valid: bool) -> void:
	if stage == Stage.BUY and valid:
		merged = true
		_try_advance_purchase()


func _try_advance_purchase() -> void:
	if purchased and merged:
		_advance(Stage.OBSERVE)


func confirm_upgrade(upgrade_present: bool, choice_ready: bool, bag_visible: bool) -> void:
	if stage == Stage.OBSERVE and upgrade_present and choice_ready and bag_visible:
		_advance(Stage.CHOOSE)


func record_reward(received: bool, was_free: bool, shelf_restored: bool) -> void:
	if stage == Stage.CHOOSE and received and was_free and shelf_restored:
		_advance(Stage.RESTORED)


func confirm_restored(shelf_restored: bool) -> void:
	if stage == Stage.RESTORED and shelf_restored:
		_advance(Stage.COMPLETE)
		completed.emit()


func _advance(next: Stage) -> void:
	stage = next
	stage_changed.emit(stage)
