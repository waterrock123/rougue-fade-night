class_name TutorialChapterPanel
extends Control

signal closed()
signal chapter_requested(chapter: TutorialChapterData)

@export var chapters: Array[TutorialChapterData] = []
@onready var chapter_list: VBoxContainer = $Panel/Margin/Content/Scroll/ChapterList
@onready var character_label: Label = $Panel/Margin/Content/CharacterLabel
@onready var notice_label: Label = $Panel/Margin/Content/NoticeLabel
var character: Character
var closing: bool = false


func _ready() -> void:
	$Panel/Margin/Content/Header/CloseButton.pressed.connect(close_panel)


func configure(current_character: Character) -> void:
	character = current_character
	character_label.text = "当前角色：%s · 章节可以独立进入、重复练习" % character.character_name
	for child: Node in chapter_list.get_children():
		chapter_list.remove_child(child)
		child.queue_free()
	for chapter: TutorialChapterData in chapters:
		if chapter != null:
			_add_chapter(chapter)


func _add_chapter(chapter: TutorialChapterData) -> void:
	var button: Button = Button.new()
	var completed: bool = ProfileManager.has_completed_tutorial_chapter(character.id, chapter.chapter_id)
	var status: String = "已完成 · 可重练" if completed else "未完成"
	button.text = "%s    [%s]\n%s" % [chapter.title, status, chapter.description]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 112)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(func() -> void: chapter_requested.emit(chapter))
	button.disabled = chapter.scene_path.is_empty() or not ResourceLoader.exists(chapter.scene_path, "PackedScene")
	chapter_list.add_child(button)


func show_error(message: String) -> void:
	notice_label.text = message


func close_panel() -> void:
	if closing:
		return
	closing = true
	hide()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
