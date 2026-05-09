class_name RestPeriod
extends Control

@export var run_stats: RunStats

@onready var shop_controller: ShopController = $UILayer/Shop
@onready var leave_button: Button = $UILayer/Button


func _ready() -> void:
	if shop_controller != null:
		# 修整期里的商店直接使用 RunStats 持有的本局商店状态。
		shop_controller.bind_run_stats(run_stats)
		shop_controller.bind_shop_runtime(_get_run_shop(), _get_run_shop_config())

	_bind_package_sell_target()

	if leave_button != null and not leave_button.pressed.is_connected(_on_leave_button_pressed):
		leave_button.pressed.connect(_on_leave_button_pressed)
	AudioController.play_bg_music("home")


func _on_leave_button_pressed() -> void:
	if shop_controller != null:
		shop_controller.cancel_free_choice_state()

	var run := _get_run()
	if run != null:
		run.finish_rest_period()


func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()

	return null


func _get_run_shop() -> Shop:
	if run_stats == null:
		return null

	return run_stats.shop


func _get_run_shop_config() -> ShopConfig:
	if run_stats == null:
		return null

	return run_stats.shop_config


func _bind_package_sell_target() -> void:
	var run := _get_run()
	if run == null or shop_controller == null:
		return

	if run.package_ui != null:
		run.package_ui.set_sell_context(run_stats, shop_controller.money_token)
