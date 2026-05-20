class_name RestPeriod
extends Control

@export var run_stats: RunStats

@onready var shop_controller: ShopController = $UILayer/Shop
@onready var leave_button: Button = $UILayer/Button
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect


func _ready() -> void:
	if shop_controller != null:
		# 修整期里的商店直接使用 RunStats 持有的本局商店状态。
		shop_controller.bind_run_stats(run_stats)
		shop_controller.bind_shop_runtime(_get_run_shop(), _get_run_shop_config())

	_bind_package_sell_target()

	if leave_button != null and not leave_button.pressed.is_connected(_on_leave_button_pressed):
		leave_button.pressed.connect(_on_leave_button_pressed)
	if not EventBus.relic_sold.is_connected(_on_relic_sold):
		EventBus.relic_sold.connect(_on_relic_sold)
	AudioController.play_bg_music("home")
	_play_enter_dialogue()


func _on_leave_button_pressed() -> void:
	if leave_button != null:
		leave_button.disabled = true
	_close_run_package_ui()

	if shop_controller != null:
		shop_controller.cancel_free_choice_state()
		if shop_controller.money_token != null:
			await shop_controller.money_token.speak_exit_and_wait()

	await _fade_to_black()

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


func _play_enter_dialogue() -> void:
	if shop_controller != null and shop_controller.money_token != null:
		shop_controller.money_token.speak_enter()


func _on_relic_sold(_relic: Relic) -> void:
	if shop_controller != null and shop_controller.money_token != null:
		shop_controller.money_token.speak_sell()


func _close_run_package_ui() -> void:
	var run := _get_run()
	if run == null:
		return

	if run.package_ui != null:
		if run.package_ui.has_method("clear_locked_mouse_relic"):
			run.package_ui.clear_locked_mouse_relic()
		run.package_ui.close_bag()
	if run.attributes_panel != null:
		run.attributes_panel.close_panel()
	if run.skill_overview_panel != null:
		run.skill_overview_panel.close_panel()


# 离开修整期前给商店老板留出说完话的时间，再做一次淡出转场。
func _fade_to_black() -> void:
	if fade_rect == null:
		return

	fade_rect.show()
	fade_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.55)
	await tween.finished
