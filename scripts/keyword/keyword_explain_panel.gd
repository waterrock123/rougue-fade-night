class_name KeywordExplainPanel
extends VBoxContainer

const KEYWORD_EXPLAIN_ENTRY_SCENE := preload("res://scenes/tooltip/keyword_explain_entry.tscn")


func setup_keywords(keywords: Array[KeywordData]) -> void:
	_clear_entries()
	visible = not keywords.is_empty()
	if keywords.is_empty():
		return

	for keyword in keywords:
		if keyword == null:
			continue

		var entry := KEYWORD_EXPLAIN_ENTRY_SCENE.instantiate() as KeywordExplainEntry
		add_child(entry)
		entry.setup(keyword)


func _clear_entries() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
