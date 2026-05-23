class_name TagEffectUI
extends FoldableContainer

const TAG_EFFECT_TOOLTIP_SCENE := preload("res://scenes/ui/tag_effect_tooltip.tscn")

@onready var item_container: VBoxContainer = $VBoxContainer/VBoxContainer
@onready var template_item: TagEffectTooltip = $VBoxContainer/VBoxContainer/TagEffectTooltip

var bound_controller: TagEffectController


func bind_controller(controller: TagEffectController) -> void:
	if bound_controller != null and bound_controller.tag_effects_changed.is_connected(refresh):
		bound_controller.tag_effects_changed.disconnect(refresh)

	bound_controller = controller
	if bound_controller != null and not bound_controller.tag_effects_changed.is_connected(refresh):
		bound_controller.tag_effects_changed.connect(refresh)
		refresh(bound_controller.get_snapshots())
	else:
		refresh([])


func refresh(snapshots: Array) -> void:
	_resolve_nodes()
	if item_container == null:
		return

	_clear_items()
	for snapshot in snapshots:
		var item := TAG_EFFECT_TOOLTIP_SCENE.instantiate() as TagEffectTooltip
		item_container.add_child(item)
		item.setup(snapshot as Dictionary)

	visible = not snapshots.is_empty()


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
