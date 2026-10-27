## 开发期Meowa帧动画工具，不启动游戏。先免费生成时间线/查价，再显式提交一次，不自动重试收费请求。
extends SceneTree

const CLIENT_SCRIPT = preload("res://scripts/utils/meowa_api_client.gd")
var client: Node
var options: Dictionary = {}
var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	client = CLIENT_SCRIPT.new()
	root.add_child(client)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("使用 plan/submit --request=res://... 或 status --job=...。")
	else:
		for arg: String in args:
			if arg.begins_with("--"):
				options[arg.get_slice("=", 0).trim_prefix("--")] = arg.get_slice("=", 1) if "=" in arg else true
		match args[0]:
			"plan", "submit": await _generate(args[0])
			"status", "wait": await _status(args[0] == "wait")
			"download": await _download()
			_: _fail("未知命令。")
	client.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _generate(command: String) -> void:
	var path: String = str(options.get("request", ""))
	var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not request is Dictionary:
		_fail("需求必须为JSON对象。")
		return
	var source: String = str(request.get("source_file", ""))
	var image: Image = Image.new()
	if not source.begins_with("res://assets/") or ".." in source or image.load(source) != OK or maxi(image.get_width(), image.get_height()) > 320:
		_fail("参考图必须为assets内不超过320像素的有效图片。")
		return
	var fields: Dictionary = request.get("fields", {}).duplicate(true)
	if not fields.has("action_timeline"):
		var prompt_reply: Dictionary = await client.post_form("/api/workflows/meowa_animation/prompts", fields, source, "source_image")
		if not _ok(prompt_reply):
			return
		fields["action_timeline"] = str(prompt_reply["data"].get("action_timeline", ""))
		if fields["action_timeline"].is_empty():
			_fail("服务没有返回动作时间线。")
			return
	fields.erase("prompt")
	fields["prepare_only"] = "true"
	var quote: Dictionary = await client.post_form("/api/workflows/meowa_animation/run", fields, source, "source_image")
	if not _ok(quote):
		return
	_save(path + ".quote.json", quote["data"])
	fields.erase("prepare_only")
	_save(path + ".prepared.json", {"source_file": source, "fields": fields})
	print("免费报价：" + JSON.stringify(quote["data"]))
	if command == "plan":
		return
	await _submit(path, fields, source, quote["data"])


func _submit(path: String, fields: Dictionary, source: String, quote: Dictionary) -> void:
	if failed:
		return
	if not options.has("confirm-spend"):
		_fail("提交需要--confirm-spend；请先检查保存的时间线。")
		return
	var cost: float = _quote_cost(quote)
	if cost < 0.0 or cost > float(options.get("max-cost", 0)):
		_fail("无法核实费用或超过本次最大点数，未提交。")
		return
	var reply: Dictionary = await client.post_form("/api/workflows/meowa_animation/run", fields, source, "source_image")
	if not _ok(reply):
		return
	_save(path + ".submission.json", reply["data"])
	print("已提交（不自动重试）：" + JSON.stringify(reply["data"]))


func _quote_cost(data: Dictionary) -> float:
	for key: String in ["credit_cost", "total_credits", "total_cost", "credits"]:
		if data.has(key) and (data[key] is float or data[key] is int):
			return float(data[key])
	for key: String in ["pricing", "cost", "billing"]:
		if data.get(key) is Dictionary:
			var nested: float = _quote_cost(data[key])
			if nested >= 0.0:
				return nested
	return -1.0


func _status(wait_for_completion: bool = false) -> void:
	var job: String = str(options.get("job", ""))
	if not job.is_valid_identifier():
		_fail("任务编号无效。")
		return
	# 等待只进行免费 GET，不重试收费 POST；十分钟后仍可用原任务号继续查询。
	var deadline: int = Time.get_ticks_msec() + 600000
	while true:
		var reply: Dictionary = await client.get_json("/api/jobs/" + job)
		if not _ok(reply):
			return
		_save("user://meowa/animation_" + job + ".json", reply["data"])
		var status: String = str(reply["data"].get("status", "unknown"))
		if not wait_for_completion or status in ["success", "failure", "cancelled"]:
			print(JSON.stringify(reply["data"]))
			if status in ["failure", "cancelled"]:
				_fail("生成任务失败或取消，不自动重新生成。")
			return
		if status not in ["queued", "pending", "running"] or Time.get_ticks_msec() >= deadline:
			_fail("停止等待，保留原任务号，请稍后继续查询。")
			return
		print("任务 %s：%s（仅查询，不扣点）" % [job, status])
		await create_timer(30.0).timeout


## 只下载已成功任务的透明产物，远程媒体地址不会携带API密钥。
func _download() -> void:
	var job: String = str(options.get("job", ""))
	var output: String = str(options.get("out", ""))
	if not job.is_valid_identifier() or not output.begins_with("res://assets/") or ".." in output or not output.ends_with(".webp.source"):
		_fail("需要有效任务编号及assets内的.webp.source路径，避免Godot把动画WebP误当静态纹理导入。")
		return
	if FileAccess.file_exists(output):
		_fail("不覆盖现有素材。")
		return
	var reply: Dictionary = await client.get_json("/api/jobs/" + job)
	if not _ok(reply) or reply["data"].get("status") != "success":
		_fail("任务未成功，不能下载。")
		return
	var result: Dictionary = reply["data"].get("result", {})
	var url: String = str(result.get("video_path", result.get("url", "")))
	if not url.begins_with("https://"):
		_fail("拒绝非HTTPS或缺失的产物地址。")
		return
	var download: Dictionary = await client.download(url)
	if not _ok(download):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		_fail("输出文件无法写入。")
		return
	file.store_buffer(download["body"])
	print("已保存：" + ProjectSettings.globalize_path(output))


func _ok(reply: Dictionary) -> bool:
	if reply.has("error"):
		_fail(str(reply["error"]))
		return false
	return true


func _save(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("无法保存素材任务记录：" + path)
		return
	file.store_string(JSON.stringify(data, "\t"))


func _fail(message: String) -> void:
	failed = true
	printerr(message)
