extends Node

const RUN_SCENE := preload("res://scenes/run/run.tscn")

@onready var continue_btn: Button = $ContinueBtn


func _ready() -> void:
	AudioController.play_bg_music("home")
	_update_continue_button()


func _on_play_btn_pressed() -> void:
	ResourceLocator.go_to_character_selector_scene()


func _on_continue_btn_pressed() -> void:
	if not SaveManager.has_continue_save():
		return

	var startup := RunStartup.new()
	startup.type = RunStartup.Type.CONTINUED_RUN
	Run.pending_startup = startup
	get_tree().change_scene_to_packed(RUN_SCENE)


func _on_exit_btn_pressed() -> void:
	get_tree().quit()


# 没有存档时禁用继续按钮，避免玩家点进一个无法恢复的空 Run。
func _update_continue_button() -> void:
	if continue_btn == null:
		return

	continue_btn.disabled = not SaveManager.has_continue_save()
