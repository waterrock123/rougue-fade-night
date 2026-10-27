## 开发期素材工具：通过 Godot --script 执行，不运行游戏主场景。
extends SceneTree

const CLIENT_SCRIPT = preload("res://scripts/utils/meowa_api_client.gd")
const MAX_REFERENCE_BYTES: int = 16 * 1024 * 1024
const ALLOWED_FIELDS: Array[String] = ["template_name", "template_config", "requirement", "aspect_ratio", "temperature",
	"resolution", "generation_provider", "quality_mode", "generation_speed", "remove_bg_method", "hd_remove_bg_mode"]

var client: Node
var options: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	client = CLIENT_SCRIPT.new()
	root.add_child(client)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		_help()
		quit(0)
		return
	options = _parse_options(arguments)
	var command: String = arguments[0]
	var kind: String = str(options.get("kind", "pixel"))
	if kind not in ["pixel", "hd"]:
		_fail("kind 仅支持 pixel 或 hd。")
		return
	match command:
		"templates": await _templates(kind)
		"history": await _print_response(await client.get_json("/api/%s-gen/history?limit=10" % kind))
		"plan", "submit": await _generate(command)
		"status", "wait", "download": await _job_command(command, kind)
		"self-test": _self_test()
		_: _help()
	quit(0 if not root.has_meta("meowa_failed") else 1)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for index in range(1, arguments.size()):
		var argument: String = arguments[index]
		if not argument.begins_with("--"):
			continue
		var separator: int = argument.find("=")
		if separator < 0:
			result[argument.substr(2)] = true
		else:
			result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result


func _templates(kind: String) -> void:
	var response: Dictionary = await client.get_json("/api/%s-gen/template-info" % kind, false)
	if response.has("error"):
		_fail(str(response["error"]))
		return
	var data: Dictionary = response["data"]
	var path: String = "user://meowa/templates_%s.json" % kind
	if not _save_json(path, data):
		_fail("模板请求成功，但无法保存本地模板列表。")
		return
	if options.has("full"):
		_print_response(response)
	else:
		var templates: Array = data.get("templates", []) if data.get("templates") is Array else []
		for entry: Variant in templates:
			if entry is Dictionary:
				print("%s | %s | 输出 %s" % [str(entry.get("template_name", "")), str(entry.get("display_name", "")), str(entry.get("output_size", ""))])
	print("完整模板参数已保存：" + ProjectSettings.globalize_path(path))


func _read_request() -> Dictionary:
	var path: String = str(options.get("request", "res://custom_resource/meowa_icon_request.example.json"))
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "无法读取需求文件。"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"error": "需求文件必须为 JSON 对象。"}
	var data: Dictionary = parser.data
	var error: String = _validate_request(data)
	return {"error": error} if not error.is_empty() else {"data": data}


func _validate_request(data: Dictionary) -> String:
	for key: String in data:
		if key not in ["kind", "fields", "reference_file"]:
			return "需求顶层仅接受 kind、fields、reference_file，不要填写密钥。"
	if str(data.get("kind", "pixel")) not in ["pixel", "hd"]:
		return "需求中的 kind 仅支持 pixel 或 hd。"
	var fields: Dictionary = data.get("fields", {}) if data.get("fields") is Dictionary else {}
	if str(fields.get("template_name", "")).strip_edges().is_empty() or str(fields.get("requirement", "")).strip_edges().is_empty():
		return "必须填写 fields.template_name 和 fields.requirement。"
	if "REPLACE_WITH" in str(fields["template_name"]):
		return "请先查询真实模板名称，替换示例中的 REPLACE_WITH_TEMPLATE_ID。"
	for key: String in fields:
		if key not in ALLOWED_FIELDS:
			return "不支持的请求字段：%s（密钥不能写进需求文件）。" % key
		if fields[key] is Dictionary and key != "template_config":
			return "仅 template_config 可填写对象。"
	if fields.has("template_config") and not fields["template_config"] is Dictionary:
		return "template_config 必须为 JSON 对象。"
	return _validate_reference(str(data.get("reference_file", "")))


func _validate_reference(path: String) -> String:
	if path.is_empty():
		return ""
	if not path.begins_with("res://assets/") or ".." in path or "\\" in path:
		return "参考图只允许选择项目 res://assets/ 内的图片。"
	if path.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp"]:
		return "参考图仅支持 PNG、JPEG、WebP。"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_REFERENCE_BYTES:
		return "参考图无法读取、为空或超过本工具的 16MB 上限。"
	return ""


func _generate(command: String) -> void:
	var request: Dictionary = _read_request()
	if request.has("error"):
		_fail(str(request["error"]))
		return
	var data: Dictionary = _prepare_request(request["data"])
	if options.get("template-defaults", false) == true:
		print("使用模板默认配置：不发送 template_config，数量与费用由模板默认值决定。")
	if command == "plan":
		print(_safe_json(data))
		print("仅预览，没有发送请求。真实费用取决于模板、模型、分辨率和抠图配置。")
		return
	if options.get("confirm-spend", false) != true:
		_fail("收费提交必须显式添加 --confirm-spend；请先运行 plan 检查。")
		return
	var kind: String = str(data.get("kind", "pixel"))
	# 只提交一次；网络中断时不重试 POST，避免重复扣点。
	var response: Dictionary = await client.post_form("/api/%s-gen" % kind, data["fields"], str(data.get("reference_file", "")))
	if response.has("error"):
		_fail(str(response["error"]))
		return
	var reply: Dictionary = response["data"]
	var job_id: String = str(reply.get("api_job_id", ""))
	if not _valid_job_id(job_id):
		_fail("提交返回值没有有效任务 ID。请先查 history，勿重复提交。")
		return
	if not _save_json(_job_dir(kind, job_id) + "/request.json", data) or not _save_json(_job_dir(kind, job_id) + "/submission.json", reply):
		_fail("任务已提交但本地记录写入失败。请保留任务 ID：" + job_id)
		return
	print("已提交 %s 任务：%s；扣点：%s" % [kind, job_id, str(reply.get("credit_cost", "服务未返回"))])
	print("请用 status 或 wait 查询；用 download 下载，不会再次提交生成。")


func _prepare_request(data: Dictionary) -> Dictionary:
	# 显式兼容模式，不修改原文件，也不在失败后偷偷重试收费请求。
	var prepared: Dictionary = data.duplicate(true)
	if options.get("template-defaults", false) == true:
		var fields: Dictionary = prepared["fields"]
		fields.erase("template_config")
	return prepared


func _job_command(command: String, kind: String) -> void:
	var job_id: String = str(options.get("job", ""))
	if not _valid_job_id(job_id):
		_fail("请提供有效的 --job=任务ID，仅允许字母、数字、下划线和连字符。")
		return
	if command == "download":
		await _download(kind, job_id)
		return
	var deadline: int = Time.get_ticks_msec() + 600000
	while true:
		var response: Dictionary = await client.get_json("/api/%s-gen/jobs?id=%s" % [kind, job_id])
		if response.has("error"):
			_fail(str(response["error"]))
			return
		var data: Dictionary = response["data"]
		_save_json(_job_dir(kind, job_id) + "/status.json", data)
		var status: String = str(data.get("status", "unknown"))
		print("任务 %s：%s" % [job_id, status])
		if command == "status" or status in ["success", "failure", "cancelled"]:
			if status == "failure":
				await _failure_diagnostics(kind, job_id)
			await _print_response(response)
			return
		if status not in ["queued", "pending", "running"] or Time.get_ticks_msec() >= deadline:
			_fail("停止轮询：未知状态或超过 10 分钟。任务未取消，可稍后再次查询。")
			return
		await create_timer(5.0).timeout


func _failure_diagnostics(kind: String, job_id: String) -> void:
	# 通用任务接口可提供错误编号，查询免费；失败不影响原始状态的展示。
	var response: Dictionary = await client.get_json("/api/jobs/" + job_id)
	if response.has("error"):
		print("补充诊断查询失败，保留原任务状态：" + _safe_json(response))
		return
	var data: Dictionary = response["data"]
	_save_json(_job_dir(kind, job_id) + "/diagnostics.json", data)
	print("补充诊断：" + _safe_json(data))


func _download(kind: String, job_id: String) -> void:
	var suffix: String = "/preview/download" if options.has("preview") else "/download"
	if options.has("output"):
		var index_text: String = str(options["output"])
		if not index_text.is_valid_int() or int(index_text) < 0:
			_fail("output 必须为非负整数。")
			return
		suffix = "/outputs/%d/download" % int(index_text)
	var response: Dictionary = await client.download("/api/%s-gen/jobs/%s%s" % [kind, job_id, suffix])
	if response.has("error"):
		_fail(str(response["error"]))
		return
	var bytes: PackedByteArray = response["body"]
	var extension: String = _asset_extension(bytes)
	if extension.is_empty():
		_fail("下载内容不是可识别的 PNG、JPEG、WebP 或 ZIP，未保存。")
		return
	var name: String = "preview" if options.has("preview") else "asset"
	if options.has("output"):
		name = "output_%d" % int(options["output"])
	var path: String = _job_dir(kind, job_id) + "/" + name + "_" + str(Time.get_ticks_usec()) + extension
	if FileAccess.file_exists(path):
		_fail("目标文件已存在，拒绝覆盖。请重新下载。")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("下载完成，但无法写入本机用户目录。")
		return
	file.store_buffer(bytes)
	file.close()
	print("已保存：" + ProjectSettings.globalize_path(path))
	print("尚未导入 assets，不覆盖现有素材；请确认效果后再使用。")


func _asset_extension(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return ".png"
	if bytes.size() >= 3 and bytes[0] == 255 and bytes[1] == 216 and bytes[2] == 255:
		return ".jpg"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return ".webp"
	if bytes.size() >= 4 and bytes.slice(0, 4) == PackedByteArray([80, 75, 3, 4]):
		return ".zip"
	return ""


func _valid_job_id(job_id: String) -> bool:
	if job_id.is_empty() or job_id.length() > 160:
		return false
	for character: String in job_id:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false
	return true


func _job_dir(kind: String, job_id: String) -> String:
	return "user://meowa/%s/%s" % [kind, job_id]


func _save_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(_safe_json(data))
	return file.get_error() == OK


func _print_response(response: Dictionary) -> void:
	if response.has("error"):
		_fail(str(response["error"]))
	else:
		var data: Dictionary = response["data"]
		print(_safe_json(data))
		if str(data.get("status", "")) in ["failure", "cancelled"]:
			_fail("任务失败或已取消，不会自动重新生成。")


func _fail(message: String) -> void:
	# 服务端数据即使回显密钥，也不在控制台打印真实 Key。
	var key: String = OS.get_environment("MEOWA_API_KEY").strip_edges()
	printerr(message.replace(key, "[REDACTED]") if not key.is_empty() else message)
	root.set_meta("meowa_failed", true)


func _safe_json(data: Dictionary) -> String:
	# 防止异常响应回显 Key 时被保存进记录或打印到日志。
	var text: String = JSON.stringify(data, "\t")
	var key: String = OS.get_environment("MEOWA_API_KEY").strip_edges()
	return text.replace(key, "[REDACTED]") if not key.is_empty() else text


func _help() -> void:
	print("Meowa 开发工具：templates | history | plan | submit | status | wait | download | self-test")
	print("选项：--kind=pixel/hd --request=res://需求.json --job=ID --preview --output=0 --full --confirm-spend --template-defaults")
	print("Key：仅从 MEOWA_API_KEY 环境变量读取，不写入项目。submit 才收费。")


func _self_test() -> void:
	# 纯本地协议与安全校验，不访问网络、不提交生成、不加载游戏场景。
	var original: Dictionary = {"fields": {"template_name": "object_1", "requirement": "测试", "template_config": {"target_count": 5}}}
	options.erase("template-defaults")
	var unchanged: Dictionary = _prepare_request(original)
	options["template-defaults"] = true
	var defaults: Dictionary = _prepare_request(original)
	options.erase("template-defaults")
	var http_error: Dictionary = client._decode_json({"code": 422, "body": '{"detail":"bad config","error_id":"test_id"}'.to_utf8_buffer()})
	var html_error: Dictionary = client._decode_json({"code": 500, "body": '<html>private</html>'.to_utf8_buffer()})
	var checks: Array[bool] = [
		unchanged["fields"].has("template_config"), not defaults["fields"].has("template_config"),
		original["fields"].has("template_config"), defaults["fields"]["requirement"] == "测试",
		http_error.get("code") == 422, str(http_error.get("error", "")).contains("bad config"),
		not str(html_error.get("error", "")).contains("private"),
		_valid_job_id("job_123-ab"), not _valid_job_id("../secret"), not _valid_job_id(""),
		_asset_extension("<html>error</html>".to_utf8_buffer()).is_empty(),
		_asset_extension(PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])) == ".png",
		_validate_request({}).length() > 0,
		_validate_request({"api_key": "test"}).length() > 0,
		_validate_request({"fields": {"template_name": "test", "requirement": "test", "Authorization": "test"}}).length() > 0,
		_validate_request({"fields": {"template_name": "test", "requirement": "测试"}}).is_empty(),
		_validate_reference("res://assets/../secret.png").length() > 0,
		client.resolve_redirect("https://api.meowa.ai/api/a", "/image.png") == "https://api.meowa.ai/image.png",
		client.resolve_redirect("https://api.meowa.ai/api/a", "https://cdn.example/image.png") == "https://cdn.example/image.png",
		client.build_form({"requirement": "中文", "template_config": {"a": 1}}, "test").get_string_from_utf8().contains("中文"),
	]
	for passed: bool in checks:
		if not passed:
			_fail("离线自检失败。")
			return
	print("离线自检通过：%d 项，无网络请求。" % checks.size())
