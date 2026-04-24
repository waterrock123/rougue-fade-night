class_name MapRoom
extends Area2D

signal clicked(room: Room)
signal selected(room: Room)
#
const ICONS := {
	Room.Type.NOT_ASSIGNED: [null, Vector2.ONE],
	Room.Type.MONSTER: [preload("res://assets/Free - Raven Fantasy Icons/Separated Files/64x64/fc226.png"), Vector2(2,2)],
	Room.Type.TREASURE: [preload("res://assets/Free - Raven Fantasy Icons/Separated Files/64x64/fc6.png"), Vector2(2,2)],
	Room.Type.CAMPFIRE: [preload("res://assets/Free - Raven Fantasy Icons/Separated Files/64x64/fc23.png"), Vector2(2, 2)],
	Room.Type.SHOP: [preload("res://assets/Free - Raven Fantasy Icons/Separated Files/64x64/fc25.png"), Vector2(2, 2)],
	Room.Type.BOSS: [preload("res://assets/Free - Raven Fantasy Icons/Separated Files/64x64/fc36.png"), Vector2(2.5, 2.5)],
	Room.Type.EVENT: [preload("res://assets/Free - Raven Fantasy Icons/Separated Files/64x64/fc13.png"), Vector2(2, 2)],
}

@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var line_2d: Line2D = $Visuals/Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var available := false : set = set_available
var room: Room : set = set_room


func set_available(new_value: bool) -> void:
	available = new_value
	
	if available:
		animation_player.play("highlight")
	elif not room.selected:
		animation_player.play("RESET")


func set_room(new_data: Room) -> void:
	room = new_data
	position = room.position
	line_2d.rotation_degrees = randi_range(0, 360)
	sprite_2d.texture = ICONS[room.type][0]
	sprite_2d.scale = ICONS[room.type][1]


func show_selected() -> void:
	line_2d.modulate = Color.WHITE


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("left_mouse"):
		return

	room.selected = true
	clicked.emit(room)
	animation_player.play("select")


func _on_map_room_selected() -> void:
	selected.emit(room)
