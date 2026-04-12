class_name AttributesPanel
extends Control

var stats_controller:StatsController
@onready var attributes_ui:Array =$GridContainer.get_children()


func setup():
	for attribute_ui in attributes_ui:
		attribute_ui.setup(stats_controller)
		EventBus.attribute_update.connect(attribute_ui.update_value) 
	close_panel()
	

	
	

func open_panel():
	
	show()

func close_panel():
	hide()
