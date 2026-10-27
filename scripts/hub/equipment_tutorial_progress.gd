@tool
class_name EquipmentTutorialProgress
extends RefCounted

## 纯步骤判定：购买、实际打开背包、真实穿戴和属性生效分别验证。
signal stage_changed(stage: int)
signal completed()
enum Stage { BUY, OPEN_BAG, EQUIP, OBSERVE, COMPLETE }
var stage: Stage = Stage.BUY


func record_purchase(received_expected_relic: bool) -> void:
	if stage == Stage.BUY and received_expected_relic:
		_advance(Stage.OPEN_BAG)


func record_bag_opened() -> void:
	if stage == Stage.OPEN_BAG:
		_advance(Stage.EQUIP)


func record_equipment(equipped: bool, stat_applied: bool) -> void:
	if stage == Stage.EQUIP and equipped and stat_applied:
		_advance(Stage.OBSERVE)
	elif stage == Stage.OBSERVE and (not equipped or not stat_applied):
		_advance(Stage.EQUIP)


func confirm_observation(equipped: bool, stat_applied: bool, attributes_visible: bool) -> void:
	if stage != Stage.OBSERVE or not equipped or not stat_applied or not attributes_visible:
		return
	_advance(Stage.COMPLETE)
	completed.emit()


func _advance(next: Stage) -> void:
	stage = next
	stage_changed.emit(stage)
