class_name AttributesPanel
extends Control

var stats_controller:StatsController
@onready var attributes_ui:Array =$Panel/MarginContainer/GridContainer.get_children()
@onready var player_health_bar: PlayerHealthBar = $Panel/PlayerHealthBar


func setup():
	for attribute_ui in attributes_ui:
		attribute_ui.setup(stats_controller)
		if not EventBus.attribute_update.is_connected(attribute_ui.update_value):
			EventBus.attribute_update.connect(attribute_ui.update_value)

	if player_health_bar != null:
		player_health_bar.setup(stats_controller)
	close_panel()
	

	
	

func open_panel():
	
	show()

func close_panel():
	hide()
