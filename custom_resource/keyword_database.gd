class_name KeywordDatabase
extends Resource

@export var keywords: Array[KeywordData] = []

var keyword_map: Dictionary = {}


func get_keyword(keyword_id: StringName) -> KeywordData:
	_ensure_keyword_map()
	return keyword_map.get(keyword_id) as KeywordData


func has_keyword(keyword_id: StringName) -> bool:
	return get_keyword(keyword_id) != null


func _ensure_keyword_map() -> void:
	if not keyword_map.is_empty():
		return

	for keyword in keywords:
		if keyword == null or keyword.id == &"":
			continue
		keyword_map[keyword.id] = keyword
