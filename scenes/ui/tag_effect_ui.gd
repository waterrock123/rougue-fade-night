class_name TagEffectUI
extends FoldableContainer

const TAG_EFFECT_TOOLTIP_SCENE := preload("res://scenes/ui/tag_effect_tooltip.tscn")

@onready var item_container: VBoxContainer = $VBoxContainer/VBoxContainer
@onready var template_item: TagEffectTooltip = $VBoxContainer/VBoxContainer/TagEffectTooltip

var bound_controller: TagEffectController
var wants_open := false
var has_display_items := false


func _ready() -> void:
	close_panel()


func bind_controller(controller: TagEffectController) -> void:
	if bound_controller != null and bound_controller.tag_effects_changed.is_connected(refresh):
		bound_controller.tag_effects_changed.disconnect(refresh)

	bound_controller = controller
	if bound_controller != null and not bound_controller.tag_effects_changed.is_connected(refresh):
		bound_controller.tag_effects_changed.connect(refresh)
		refresh(bound_controller.get_snapshots())
	else:
		refresh([])


func open_panel() -> void:
	wants_open = true
	if bound_controller != null:
		refresh(bound_controller.get_snapshots())
	else:
		_apply_visibility()


func close_panel() -> void:
	wants_open = false
	_apply_visibility()


func refresh(snapshots: Array) -> void:
	_resolve_nodes()
	if item_container == null:
		return

	_clear_items()
	var display_snapshots := _filter_display_snapshots(snapshots)
	for snapshot in display_snapshots:
		var item := TAG_EFFECT_TOOLTIP_SCENE.instantiate() as TagEffectTooltip
		item_container.add_child(item)
		item.setup(snapshot as Dictionary)

	has_display_items = not display_snapshots.is_empty()
	_apply_visibility()


func _filter_display_snapshots(snapshots: Array) -> Array:
	var result := []
	for snapshot in snapshots:
		if not (snapshot is Dictionary):
			continue

		var snapshot_dict := snapshot as Dictionary
		# 只有玩家当前背包或装备栏里出现过对应 tag，才展示这条套装效果说明。
		if bool(snapshot_dict.get("has_owned_tag", int(snapshot_dict.get("count", 0)) > 0)):
			result.append(snapshot)
	return result


func _apply_visibility() -> void:
	visible = wants_open and has_display_items


func _clear_items() -> void:
	for child in item_container.get_children():
		if child == template_item:
			child.hide()
			continue
		child.queue_free()


func _resolve_nodes() -> void:
	if item_container == null:
		item_container = get_node_or_null("VBoxContainer/VBoxContainer") as VBoxContainer
	if template_item == null:
		template_item = get_node_or_null("VBoxContainer/VBoxContainer/TagEffectTooltip") as TagEffectTooltip
