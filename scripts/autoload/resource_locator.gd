
extends Node

var _play_scene:PlayScene = null

var packed_play_scene: PackedScene = preload("res://scenes/play_scene.tscn")
var packed_home_scene: PackedScene = preload("res://scenes/home_scene.tscn")
var packed_character_selector_scene: PackedScene = preload("res://scenes/character_selector.tscn")
var packed_pictorial_book_scene: PackedScene = preload("res://scenes/ui/pictorial_book.tscn")

#func _ready():
	#_play_scene = get_tree().root.get_node("PlayScene")
#
#
#func get_play_scene() -> PlayScene :
	##if _play_scene == null: 
		##_play_scene = get_tree().root.get_node("PlayScene")
		##
	##return _play_scene

func go_to_play_scene():
	
	get_tree().change_scene_to_packed(packed_play_scene)

func go_to_character_selector_scene():
	get_tree().change_scene_to_packed(packed_character_selector_scene)


func go_to_pictorial_book_scene():
	get_tree().change_scene_to_packed(packed_pictorial_book_scene)

func go_to_home_scene():
	# 如果当前还在一局 Run 里，回主菜单前先保存一次，方便“继续游戏”接上。
	var current_run := get_tree().get_first_node_in_group("run") as Run
	if current_run != null:
		current_run.save_current_run()
	EventBus.scene_changed.emit("home")
	get_tree().change_scene_to_packed(packed_home_scene)
