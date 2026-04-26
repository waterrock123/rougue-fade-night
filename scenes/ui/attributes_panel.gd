class_name AttributesPanel
extends Control

var stats_controller: StatsController

@onready var attributes_ui: Array = $Panel/MarginContainer/GridContainer.get_children()
@onready var player_health_bar: PlayerHealthBar = $Panel/PlayerHealthBar


func setup() -> void:
	if stats_controller == null:
		return

	for attribute_ui in attributes_ui:
		attribute_ui.setup(stats_controller)
		if not EventBus.attribute_update.is_connected(attribute_ui.update_value):
			EventBus.attribute_update.connect(attribute_ui.update_value)

	if player_health_bar != null:
		player_health_bar.setup(stats_controller)


func open_panel() -> void:
	show()


func close_panel() -> void:
	hide()
