class_name KeywordTextFormatter
extends RefCounted


static func format_text(raw_text: String, keyword_database: KeywordDatabase) -> KeywordTextResult:
	var result := KeywordTextResult.new()
	if raw_text.is_empty():
		return result

	var regex := RegEx.new()
	var compile_error := regex.compile("\\{([^{}]+)\\}")
	if compile_error != OK:
		result.bbcode_text = _escape_bbcode(raw_text)
		return result

	var matches := regex.search_all(raw_text)
	var cursor := 0
	var output := ""

	for match_result in matches:
		output += _escape_bbcode(raw_text.substr(cursor, match_result.get_start() - cursor))

		var keyword_id := StringName(match_result.get_string(1))
		var keyword := keyword_database.get_keyword(keyword_id) if keyword_database != null else null
		if keyword == null:
			# 找不到词条时保留原文，方便我们在编辑资源时发现拼写问题。
			output += _escape_bbcode(match_result.get_string(0))
		else:
			output += _build_keyword_bbcode(keyword)
			result.add_keyword(keyword)

		cursor = match_result.get_end()

	output += _escape_bbcode(raw_text.substr(cursor))
	result.bbcode_text = output
	return result


# 将 {keyword} 转成纯文本名称，给普通 Label 使用；需要颜色时仍然使用 format_text。
static func format_text_plain(raw_text: String, keyword_database: KeywordDatabase) -> String:
	if raw_text.is_empty():
		return ""

	var regex := RegEx.new()
	var compile_error := regex.compile("\\{([^{}]+)\\}")
	if compile_error != OK:
		return raw_text

	var matches := regex.search_all(raw_text)
	var cursor := 0
	var output := ""

	for match_result in matches:
		output += raw_text.substr(cursor, match_result.get_start() - cursor)

		var keyword_id := StringName(match_result.get_string(1))
		var keyword := keyword_database.get_keyword(keyword_id) if keyword_database != null else null
		output += keyword.display_name if keyword != null else match_result.get_string(0)

		cursor = match_result.get_end()

	output += raw_text.substr(cursor)
	return output


static func _build_keyword_bbcode(keyword: KeywordData) -> String:
	var color_html := keyword.color.to_html(false)
	var keyword_name: String = _escape_bbcode(keyword.display_name)
	return "[color=#%s]%s[/color]" % [color_html, keyword_name]


static func _escape_bbcode(text: String) -> String:
	# RichTextLabel 会解析 []，所以普通描述里的方括号需要转义，避免误当成 BBCode。
	return text.replace("[", "[lb]").replace("]", "[rb]")
