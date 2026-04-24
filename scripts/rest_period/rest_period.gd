class_name RestPeriod
extends Control

@export var run_stats: RunStats

@onready var player_build_proxy: PlayerBuildProxy = $PlayerBuildProxy
@onready var package_ui: PackageUI = $UILayer/PackageUI
@onready var attributes_panel: AttributesPanel = $UILayer/AttributesPanel
@onready var shop_controller: ShopController = $UILayer/Shop
@onready var leave_button: Button = $UILayer/Button


func _ready() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	var player_build := run_stats.player_build

	package_ui.open_bag(player_build.player_inventory, player_build.player_equipment)
	attributes_panel.stats_controller = player_build_proxy.get_stats_controller()
	attributes_panel.setup()
	attributes_panel.open_panel()

	if shop_controller != null:
		shop_controller.bind_run_stats(run_stats)

	if leave_button != null and not leave_button.pressed.is_connected(_on_leave_button_pressed):
		leave_button.pressed.connect(_on_leave_button_pressed)


func _on_leave_button_pressed() -> void:
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
