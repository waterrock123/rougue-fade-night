@tool
extends EditorPlugin

const WORKSHOP: Script = preload("res://addons/battle_map_workshop/workshop_window.gd")
var workshop: Window


func _enter_tree() -> void:
	add_tool_menu_item("战斗地图工坊", _open_workshop)


func _exit_tree() -> void:
	remove_tool_menu_item("战斗地图工坊")
	if is_instance_valid(workshop):
		workshop.queue_free()


func _open_workshop() -> void:
	if not is_instance_valid(workshop):
		workshop = WORKSHOP.new()
		get_editor_interface().get_base_control().add_child(workshop)
		workshop.connect("template_saved", _on_template_saved)
	workshop.popup_centered(Vector2i(1260, 800))


func _on_template_saved(path: String) -> void:
	get_editor_interface().get_resource_filesystem().scan()
	print("地图工坊已保存新模板（未加入正式地图池）：", path)
