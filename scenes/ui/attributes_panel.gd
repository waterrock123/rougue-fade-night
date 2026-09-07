class_name AttributesPanel
extends Control

var stats_controller: StatsController
var attributes_ui: Array[AttributeUI] = []

@onready var primary_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/PrimaryGrid
@onready var combat_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/CombatGrid
@onready var player_health_bar: PlayerHealthBar = $Panel/MarginContainer/VBoxContainer/PlayerHealthBar


## 绑定 StatsController，并让一级属性和派生战斗属性使用同一套刷新链路。
func setup() -> void:
	if stats_controller == null:
		return

	_collect_attribute_ui()
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


func _collect_attribute_ui() -> void:
	attributes_ui.clear()
	for child: Node in primary_grid.get_children():
		if child is AttributeUI:
			attributes_ui.append(child as AttributeUI)
	for child: Node in combat_grid.get_children():
		if child is AttributeUI:
			attributes_ui.append(child as AttributeUI)
