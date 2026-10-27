## 开发期 HTTP 客户端，不挂载到游戏场景，不包含密钥常量。
extends Node

const BASE_URL: String = "https://api.meowa.ai"
const MAX_BODY_BYTES: int = 32 * 1024 * 1024


func get_json(path: String, authenticated: bool = true) -> Dictionary:
	var response: Dictionary = await _request(BASE_URL + path, HTTPClient.METHOD_GET, PackedByteArray(), "", authenticated)
	return _decode_json(response)


func post_form(path: String, fields: Dictionary, reference_path: String = "", file_field: String = "reference_file") -> Dictionary:
	var boundary: String = "MeowaGodot%s" % Time.get_ticks_usec()
	var payload: PackedByteArray = build_form(fields, boundary)
	if not reference_path.is_empty():
		payload.append_array(_file_part(reference_path, boundary, file_field))
	payload.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())
	var response: Dictionary = await _request(BASE_URL + path, HTTPClient.METHOD_POST, payload,
		"multipart/form-data; boundary=" + boundary, true)
	return _decode_json(response)


func build_form(fields: Dictionary, boundary: String) -> PackedByteArray:
	var payload := PackedByteArray()
	for key: String in fields:
		var value: String = JSON.stringify(fields[key]) if fields[key] is Dictionary else str(fields[key])
		var part: String = "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
		payload.append_array((part % [boundary, key, value]).to_utf8_buffer())
	return payload


func _file_part(path: String, boundary: String, file_field: String = "reference_file") -> PackedByteArray:
	# 使用固定上传文件名，避免路径或特殊字符进入 multipart 请求头。
	var extension: String = path.get_extension().to_lower()
	var mime: String = "image/jpeg" if extension in ["jpg", "jpeg"] else "image/" + extension
	var header: String = "--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"reference.%s\"\r\nContent-Type: %s\r\n\r\n"
	var part: PackedByteArray = (header % [boundary, file_field, extension, mime]).to_utf8_buffer()
	part.append_array(FileAccess.get_file_as_bytes(path))
	part.append_array("\r\n".to_utf8_buffer())
	return part


func _request(url: String, method: int, body: PackedByteArray, content_type: String, authenticated: bool) -> Dictionary:
	var headers := PackedStringArray()
	if authenticated:
		var key: String = OS.get_environment("MEOWA_API_KEY").strip_edges()
		if key.is_empty() or "\n" in key or "\r" in key:
			return {"error": "请先配置本机 MEOWA_API_KEY 环境变量。"}
		# 密钥只发往官方 API，下载重定向到其他域名时不携带认证头。
		if not url.begins_with(BASE_URL + "/"):
			return {"error": "拒绝向非官方地址发送密钥。"}
		headers.append("Authorization: Bearer " + key)
	if not content_type.is_empty():
		headers.append("Content-Type: " + content_type)
	var request := HTTPRequest.new()
	request.timeout = 90.0
	request.body_size_limit = MAX_BODY_BYTES
	request.max_redirects = 0
	add_child(request)
	var start_error: Error = request.request_raw(url, headers, method, body)
	if start_error != OK:
		request.queue_free()
		return {"error": "无法发起请求，错误码 %d。未自动重试。" % start_error}
	var reply: Array = await request.request_completed
	request.queue_free()
	if int(reply[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "网络请求未完成（%d）。提交结果可能未知，请查历史，勿直接重复提交。" % int(reply[0])}
	return {"code": int(reply[1]), "headers": reply[2], "body": reply[3]}


func _decode_json(response: Dictionary) -> Dictionary:
	if response.has("error"):
		return response
	var code: int = int(response.get("code", 0))
	var parser := JSON.new()
	var bytes: PackedByteArray = response["body"]
	var valid_json: bool = parser.parse(bytes.get_string_from_utf8()) == OK and parser.data is Dictionary
	if code < 200 or code >= 300:
		# 保留结构化错误，避免把参数校验、认证和余额问题混为一谈；不回显 HTML。
		var details: Dictionary = {}
		if valid_json:
			var data: Dictionary = parser.data
			for field: String in ["detail", "error", "message", "error_code", "error_id"]:
				if data.has(field):
					details[field] = data[field]
		var message: String = "API 返回 HTTP %d：%s" % [code, JSON.stringify(details).left(2000)]
		var key: String = OS.get_environment("MEOWA_API_KEY").strip_edges()
		if not key.is_empty():
			message = message.replace(key, "[REDACTED]")
		return {"error": message, "code": code}
	if not valid_json:
		return {"error": "API 未返回预期的 JSON 对象。"}
	return {"data": parser.data}


func download(path: String) -> Dictionary:
	var url: String = path if path.begins_with("https://") else BASE_URL + path
	for redirect_index in range(6):
		if not url.begins_with("https://"):
			return {"error": "拒绝非 HTTPS 下载。"}
		var response: Dictionary = await _request(url, HTTPClient.METHOD_GET, PackedByteArray(), "", url.begins_with(BASE_URL + "/"))
		if response.has("error"):
			return response
		var code: int = int(response["code"])
		if code in [301, 302, 303, 307, 308]:
			var location: String = _header_value(response["headers"], "location")
			if location.is_empty():
				return {"error": "下载重定向缺少目标地址。"}
			url = resolve_redirect(url, location)
			continue
		if code < 200 or code >= 300:
			return {"error": "下载返回 HTTP %d，可能任务尚未完成。" % code}
		return response
	return {"error": "下载重定向次数过多。"}


func resolve_redirect(current_url: String, location: String) -> String:
	if location.begins_with("//"):
		return "https:" + location
	if location.begins_with("/"):
		return current_url.get_slice("/", 0) + "//" + current_url.get_slice("/", 2) + location
	if "://" in location:
		return location
	return current_url.get_base_dir() + "/" + location


func _header_value(headers: PackedStringArray, name: String) -> String:
	for header: String in headers:
		if header.to_lower().begins_with(name.to_lower() + ":"):
			return header.substr(header.find(":") + 1).strip_edges()
	return ""
