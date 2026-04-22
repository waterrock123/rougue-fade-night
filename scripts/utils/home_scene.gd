extends Node


func _ready() -> void:
	AudioController.play_bg_music("home")


func _on_play_btn_pressed() -> void:
	ResourceLocator.go_to_character_selector_scene()


func _on_exit_btn_pressed() -> void:
	get_tree().quit()
