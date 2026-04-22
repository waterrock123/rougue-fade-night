class_name RunStats
extends Resource

#初始金币，默认为0
const STARTING_GOLD := 0
#每次修整期获得金币
const EACH_TURN_GOLD: = 6




@export var gold := STARTING_GOLD : set = set_gold
@export var player_build:PlayerBuild


func set_gold(new_amount: int) -> void:
	gold = new_amount
	if Engine.is_editor_hint():
		return

	if EventBus != null:
		EventBus.gold_changed.emit()
