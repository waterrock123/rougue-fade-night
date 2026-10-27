
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


## 中途离场沿用 Run 的检查点规则；结束画面传 false，防止重新写回已删除的存档。
func go_to_hub_scene(preserve_run: bool = true) -> void:
	var current_run: Run = get_tree().get_first_node_in_group("run") as Run
	var hub_startup: RunStartup = RunStartup.new()
	if current_run != null:
		if preserve_run:
			current_run.save_current_run()
		if current_run.run_stats != null:
			hub_startup.picked_character = current_run.run_stats.picked_character
	hub_startup.type = RunStartup.Type.NEW_RUN
	MainHomeMap.pending_startup = hub_startup
	Run.pending_startup = null
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file("res://scenes/hub/main_home_map.tscn")
	if error != OK:
		MainHomeMap.pending_startup = null
		push_error("返回大厅失败：%s" % error_string(error))
