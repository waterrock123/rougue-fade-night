class_name KeywordTextResult
extends RefCounted

var bbcode_text: String = ""
var keywords: Array[KeywordData] = []


func add_keyword(keyword: KeywordData) -> void:
	if keyword == null:
		return
	if keywords.has(keyword):
		return
	keywords.append(keyword)
