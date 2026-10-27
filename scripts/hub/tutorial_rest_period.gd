extends RestPeriod


func _ready() -> void:
	super._ready()
	leave_button.hide()


## 入门章不开放出售，避免刚买到教学装备就卖掉而卡住穿戴步骤。
func _bind_package_sell_target() -> void:
	pass


func _on_leave_button_pressed() -> void:
	pass
