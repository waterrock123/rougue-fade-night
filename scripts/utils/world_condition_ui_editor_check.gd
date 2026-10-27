## 只在编辑器检查场景布局和CanvasLayer关系，不加入场景树、不启动游戏。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_layout()
	print("天气环境UI编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_layout() -> void:
	var scene: PackedScene = load("res://scenes/run/run.tscn") as PackedScene
	_check(scene != null, "Run场景可加载")
	if scene == null:
		return
	var run: Node = scene.instantiate()
	var weather_layer: CanvasLayer = run.get_node("Map/ConditionUILayer") as CanvasLayer
	var ui_layer: CanvasLayer = run.get_node("UI") as CanvasLayer
	var top_bar: CanvasLayer = run.get_node("TopBar") as CanvasLayer
	var panel: Control = weather_layer.get_node("WorldConditionDisplay") as Control
	_check(panel.offset_left == 24.0 and panel.offset_top == 72.0, "天气环境显示在左上角")
	_check(panel.offset_right == 470.0 and panel.offset_bottom == 195.0, "保留原面板尺寸")
	_check(weather_layer.layer == 1 and ui_layer.layer == 2, "地图摘要低于常驻UI")
	_check(run.get_node("UI/DebugConsole").get_parent() == ui_layer, "调试界面仍使用原节点路径")
	_check(weather_layer.layer < ui_layer.layer, "调试界面能够覆盖天气面板")
	_check(top_bar.layer == 3, "顶部操作栏层级保持不变")
	_check(panel.get_node_or_null("%WeatherLabel") != null and panel.get_node_or_null("%EnvironmentLabel") != null, "天气环境标签绑定不变")
	run.free()
