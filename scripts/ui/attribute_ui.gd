class_name AttributeUI
extends Control


@export var icon:Texture2D
var stats_controller:StatsController
@export var attribute:String
var value:int

@onready var Icon:TextureRect = $Panel/HBoxContainer/Icon
@onready var ValueLabel: Label = $Panel/HBoxContainer/DataLabel

func setup(_stats_controller):
	Icon.texture = icon
	stats_controller = _stats_controller
	update_value()

func update_value():
	value = int(stats_controller.get_stat(attribute))
	ValueLabel.text = str(value)
