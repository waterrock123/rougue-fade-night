extends Node

const RUN_SCENE := preload("res://scenes/run/run.tscn")
const TAG_EFFECT_CHOSE_PANEL_SCENE := preload("res://scenes/tag_effect_chose_panel.tscn")
const SETTING_SCENE := preload("res://scenes/setting_scene.tscn")

@onready var continue_btn: Button = $ContinueBtn
@onready var tag_set_button: Button = $TagSetButton
@onready var book_button: Button = $BookButton
@onready var setting_button: Button = $SettingButton

var tag_effect_panel: TagEffectChosePanel
var setting_scene: SettingScene


func _ready() -> void:
	AudioController.play_bg_music("home")
	_update_continue_button()
	if tag_set_button != null and not tag_set_button.pressed.is_connected(_on_tag_set_button_pressed):
		tag_set_button.pressed.connect(_on_tag_set_button_pressed)
	if book_button != null and not book_button.pressed.is_connected(_on_book_button_pressed):
		book_button.pressed.connect(_on_book_button_pressed)
	if setting_button != null and not setting_button.pressed.is_connected(_on_setting_button_pressed):
		setting_button.pressed.connect(_on_setting_button_pressed)


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


func _on_book_button_pressed() -> void:
	ResourceLocator.go_to_pictorial_book_scene()


func _on_tag_set_button_pressed() -> void:
	if tag_effect_panel != null and is_instance_valid(tag_effect_panel):
		return

	tag_effect_panel = TAG_EFFECT_CHOSE_PANEL_SCENE.instantiate() as TagEffectChosePanel
	add_child(tag_effect_panel)
	tag_effect_panel.closed.connect(_on_tag_effect_panel_closed)


func _on_tag_effect_panel_closed() -> void:
	tag_effect_panel = null


func _on_setting_button_pressed() -> void:
	if setting_scene != null and is_instance_valid(setting_scene):
		return

	setting_scene = SETTING_SCENE.instantiate() as SettingScene
	add_child(setting_scene)
	setting_scene.closed.connect(_on_setting_scene_closed)


func _on_setting_scene_closed() -> void:
	setting_scene = null


# 没有存档时禁用继续按钮，避免玩家点进一个无法恢复的空 Run。
func _update_continue_button() -> void:
	if continue_btn == null:
		return

	continue_btn.disabled = not SaveManager.has_continue_save()
