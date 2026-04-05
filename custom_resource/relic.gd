class_name Relic
extends Resource

enum CharacterType {ALL,WARRIOR,RANGER}

@export var relic_name: String
@export var id: String
@export var character_type: CharacterType
@export var icon: Texture
@export_multiline var tooltip: String

func initialize_relic(_owner: RelicUI) -> void:
	pass


func activate_relic(_owner: RelicUI) -> void:
	pass


func deactivate_relic(_owner: RelicUI) -> void:
	pass


func get_tooltip() -> String:
	return tooltip
