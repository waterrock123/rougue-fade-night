class_name PauseMenu
extends VBoxContainer

@onready var resume_btn: Button = $ResumeBtn
@onready var exit_btn: Button = $ExitBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
 

func _on_resume_btn_pressed() -> void:
	EventBus.game_paused.emit(false)
	EventBus.change_bag.emit()
	get_tree().paused = false
	hide()

func _on_exit_btn_pressed() -> void:
	get_tree().paused = false
	ResourceLocator.go_to_home_scene()
	
