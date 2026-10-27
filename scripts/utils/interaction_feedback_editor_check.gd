## 只在编辑器隔离执行，不启动游戏，不写真实存档或按键配置。
extends "res://scripts/utils/merge_tutorial_editor_check.gd"

func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	if OS.get_cmdline_user_args().has("--layout-only"):
		await _check_upgrade_layout()
		print("升级按钮布局检查：%d项，失败%d项。" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	_check_progress()
	_check_characters()
	_check_preview_events()
	_check_damage_filter()
	_check_profile()
	_check_equipment_progress()
	_check_chapter_profile()
	_check_equipment_lessons()
	_check_fixed_shelf()
	_check_chapter_resources()
	_check_merge_progress()
	_prepare_pipeline_fixtures()
	_check_merge_pipeline()
	_check_material_capacity()
	_check_late_material_return()
	_check_tip_limiter()
	_check_cast_reasons()
	_check_upgrade_actions()
	_check_binding_labels()
	_check_inventory_feedback()
	_check_consumable_feedback()
	_check_shop_failures()
	await _check_feedback_ui()
	await _check_upgrade_layout()
	await _check_observation_layout()
	await _check_chapter_layout()
	print("交互反馈、商店升级与教学回归：%d项，失败%d项；未启动游戏、未写真实存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_tip_limiter() -> void:
	var limiter: RefCounted = (load("res://scripts/ui/action_tip_limiter.gd") as GDScript).new()
	_check(limiter.call("acquire", "skill:energy", 0), "同类操作第一次可提示")
	_check(not limiter.call("acquire", "skill:energy", 10), "长按重试不会每帧提示")
	_check(limiter.call("acquire", "skill:material", 10), "不同失败原因不互相屏蔽")
	_check(limiter.call("acquire", "skill:energy", 900), "限频后仍能再次提示，不永久静音")
	for index: int in range(200):
		limiter.call("acquire", "test:%d" % index, 2000)
	_check(limiter.get("last_shown").size() <= 128, "提示历史有容量上限")
	var source: String = _function_source("res://scripts/autoload/float_text.gd", "show_screen_tip")
	_check(not source.contains("action_tip_limiter"), "不对真实掉落与奖励日志去重")


func _check_cast_reasons() -> void:
	var methods: String = ""
	for method: String in ["get_cast_block_info", "request_player_cast", "trigger_held_ability_by_idx"]:
		methods += _function_source(CONTROLLER_PATH, method) + "\n"
	methods = methods.replace(": Ability", ": Node")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar entity: Node\nvar abilities: Array[Node] = []\nvar cooldowns: Dictionary = {}\nvar blocked: bool = false\nvar energy_ok: bool = true\nvar reports: int = 0\nvar casts: int = 0\nfunc _can_be_cast(ability) -> bool:\n\treturn not entity.is_dead and get_cast_block_info(ability).is_empty()\nfunc _is_cast_blocked(_ability) -> bool:\n\treturn blocked\nfunc get_modified_energy_cost(_ability) -> float:\n\treturn 10.0\nfunc _has_enough_ability_energy(_cost) -> bool:\n\treturn energy_ok\nfunc _show_ability_block_reason(_ability) -> void:\n\treports += 1\nfunc trigger_ability(_ability, _charge: float = 0.0) -> bool:\n\tcasts += 1\n\treturn true\n" + methods)
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar is_dead: bool = false\nvar locked: bool = false\nvar reason: String = \"\"\nfunc can_act() -> bool:\n\treturn not locked\nfunc get_activation_block_reason(_caster) -> String:\n\treturn reason\nfunc has_cast_preview() -> bool:\n\treturn false\n")
	if script == null or actor_script == null:
		return
	var helper: RefCounted = script.new()
	var actor: Node = actor_script.new()
	var ability: Node = actor_script.new()
	helper.set("entity", actor)
	helper.get("abilities").append(ability)
	actor.set("locked", true)
	_check(helper.call("get_cast_block_info", ability).get("key") == "control", "受控时说明不能行动")
	actor.set("locked", false)
	helper.set("blocked", true)
	_check(helper.call("get_cast_block_info", ability).get("key") == "disabled", "局部技能禁用有独立原因")
	helper.set("blocked", false)
	helper.get("cooldowns")[ability] = 2.0
	helper.call("request_player_cast", ability)
	_check(helper.get("reports") == 1 and helper.get("casts") == 0, "主动点击冷却技能会反馈但不会施法")
	for frame: int in range(60):
		helper.call("trigger_held_ability_by_idx", 0)
	_check(helper.get("reports") == 1, "长按等待冷却不重复反馈")
	helper.get("cooldowns")[ability] = 0.0
	helper.set("energy_ok", false)
	_check(helper.call("get_cast_block_info", ability).get("key") == "energy", "能量不足有明确提示")
	helper.set("energy_ok", true)
	ability.set("reason", "背包没有可用弹药")
	_check(helper.call("get_cast_block_info", ability).get("message") == "背包没有可用弹药", "保留成本组件提供的准确原因")
	ability.set("reason", "")
	_check(helper.call("request_player_cast", ability) and helper.get("casts") == 1, "合法输入只触发一次实际施法")
	_check(not _function_source(CONTROLLER_PATH, "trigger_ability").contains("_show_ability_block_reason"), "自动技能和AI施法不污染玩家提示")
	actor.free()
	ability.free()


func _upgrade_fixture() -> RefCounted:
	var source: String = ""
	for method: String in ["_on_level_up_button_pressed", "_set_level_up_pending", "_get_upgrade_block_reason", "_refresh_level_up_button", "get_level_data", "level_up", "_process", "_input"]:
		source += _function_source(CORE_SHOP, method) + "\n"
	source = source.replace("Time.get_ticks_msec()", "now_msec").replace("get_viewport()", "test_viewport").replace("level_up_button.get_global_mouse_position()", "mouse_position")
	var header: String = "@tool\nextends RefCounted\nvar shop: Shop\nvar shop_config: ShopConfig\nvar run_stats: RunStats\nvar level_up_button: Button\nvar upgrade_view: RefCounted\nvar upgrade_confirmation: RefCounted = preload(\"res://scripts/rest_period/shop_upgrade_confirmation.gd\").new()\nvar is_level_up_pending: bool = false\nvar now_msec: int = 1000\nvar test_viewport: RefCounted\nvar mouse_position: Vector2 = Vector2(-10, -10)\nvar saved: int = 0\nvar messages: Array[String] = []\nvar rolls: Array[int] = []\nfunc _show_shop_tip(message: String, _key: String) -> void:\n\tmessages.append(message)\nfunc _clear_pending_purchase() -> void:\n\tpass\nfunc _update_shop_ui() -> void:\n\t_refresh_level_up_button()\nfunc _rebuild_shop_buttons() -> void:\n\tpass\nfunc _sync_shop_ui() -> void:\n\tpass\nfunc _roll_slots(start: int) -> void:\n\trolls.append(start)\nfunc _save_run_if_available() -> void:\n\tsaved += 1\n"
	var script: GDScript = _fixture(header + source)
	return script.new() if script != null else null


func _check_upgrade_actions() -> void:
	var helper: RefCounted = _upgrade_fixture()
	if helper == null:
		return
	var view_script: GDScript = _fixture("@tool\nextends RefCounted\nvar last: Array = []\nfunc display(level: int, next: int, price: int, added: int, pending: bool, affordable: bool) -> void:\n\tlast = [level, next, price, added, pending, affordable]\nfunc set_input_as_handled() -> void:\n\tpass\n")
	var shop: Resource = (load("res://scripts/rest_period/shop/shop.gd") as GDScript).new()
	shop.call("ensure_slot_count")
	var stats: Resource = (load("res://scripts/run/run_stats.gd") as GDScript).new()
	stats.set("gold", 6)
	stats.get("pending_free_relic_choice_levels").append(2)
	var config: Resource = (load("res://scripts/rest_period/shop/shop_config.gd") as GDScript).new()
	var level: Resource = (load("res://scripts/rest_period/shop/shop_level_data.gd") as GDScript).new()
	level.set("level", 2)
	level.set("upgrade_cost", 7)
	level.get("effects").append((load("res://scripts/rest_period/shop/add_slot_effect.gd") as GDScript).new())
	config.get("level_data").append(level)
	var button: Button = Button.new()
	button.size = Vector2(210, 230)
	helper.set("shop", shop)
	helper.set("shop_config", config)
	helper.set("run_stats", stats)
	helper.set("level_up_button", button)
	helper.set("upgrade_view", view_script.new())
	helper.set("test_viewport", view_script.new())
	helper.call("_on_level_up_button_pressed")
	_check(not helper.get("is_level_up_pending") and stats.get("gold") == 6, "金币不足不进入确认、不扣费")
	stats.set("gold", 20)
	helper.call("_on_level_up_button_pressed")
	_check(helper.get("is_level_up_pending") and shop.get("level") == 1 and stats.get("gold") == 20, "首次点击只预览，不直接升级")
	_check_cancel_upgrade(helper)
	_check_confirm_upgrade(helper, shop, stats)
	button.free()


func _check_cancel_upgrade(helper: RefCounted) -> void:
	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	helper.call("_input", escape)
	_check(not helper.get("is_level_up_pending"), "Esc取消升级确认")
	helper.call("_on_level_up_button_pressed")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	helper.call("_input", click)
	_check(not helper.get("is_level_up_pending"), "点击别处取消确认且不执行升级")
	helper.call("_on_level_up_button_pressed")
	helper.set("now_msec", 5001)
	helper.call("_process", 0.1)
	_check(not helper.get("is_level_up_pending"), "4秒超时自动取消确认")


func _check_confirm_upgrade(helper: RefCounted, shop: Resource, stats: Resource) -> void:
	helper.call("_on_level_up_button_pressed")
	var level: Resource = helper.get("shop_config").get("level_data")[0]
	level.set("upgrade_cost", 8)
	helper.call("_on_level_up_button_pressed")
	_check(shop.get("level") == 1 and stats.get("gold") == 20, "确认期间价格变化时重新确认，不能直接扣新价格")
	helper.call("_on_level_up_button_pressed")
	_check(shop.get("level") == 2 and stats.get("gold") == 12, "二次确认只扣一次正确费用")
	_check(shop.get("slot_count") == 5 and helper.get("rolls") == [4], "扩容只补新增货架，不重刷原商品")
	_check(helper.get("saved") == 1, "升级成功只保存一次")
	_check(stats.get("pending_free_relic_choice_levels") == [2], "升级不改变已经锁定的免费奖励等阶")
	_check(helper.get("level_up_button").get("disabled"), "最高等级禁用升级按钮")
	var confirmation: RefCounted = helper.get("upgrade_confirmation")
	_check(not confirmation.call("is_active", 5001), "升级完成后不保留待确认状态")


func _check_binding_labels() -> void:
	var formatter_source: String = ""
	for method: String in ["get_event_display_text", "_get_key_event_text", "_get_mouse_event_text"]:
		formatter_source += _function_source("res://scripts/autoload/input_settings_manager.gd", method) + "\n"
	var formatter_script: GDScript = _fixture("@tool\nextends RefCounted\n" + formatter_source)
	var source: String = _function_source("res://scripts/ui/input_binding_display.gd", "action_text").replace("InputSettingsManager", "formatter")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar formatter: RefCounted\n" + source)
	if script == null or formatter_script == null:
		return
	var labels: RefCounted = script.new()
	labels.set("formatter", formatter_script.new())
	var action: StringName = &"__interaction_feedback_test"
	InputMap.add_action(action)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	InputMap.action_add_event(action, key)
	_check(labels.call("action_text", action) == "K", "键位标签读取真实InputMap而不是槽位序号")
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event(action, mouse)
	_check(str(labels.call("action_text", action, true)).contains("\n"), "两个备选绑定分行显示")
	InputMap.action_erase_events(action)
	_check(labels.call("action_text", action) == "未绑定", "清空按键后明确显示未绑定")
	InputMap.erase_action(action)
	var body: String = FileAccess.get_file_as_string("res://scripts/utils/spell_bar.gd")
	_check(body.contains("bindings_changed.connect") and not body.contains("binded_key = str(i)"), "改键信号会刷新技能栏文字")


func _check_feedback_ui() -> void:
	var previous_size: Vector2i = root.size
	root.size = Vector2i(1920, 1080)
	var source: String = FileAccess.get_file_as_string("res://scripts/autoload/float_text.gd")
	var script: GDScript = _fixture("@tool\n" + source)
	if script == null:
		return
	var node: Node = script.new()
	root.add_child(node)
	node.call("show_action_tip", "金币不足", "test:gold")
	var label: Label = node.get("screen_tip_label") as Label
	node.call("show_action_tip", "装备栏已满", "test:full")
	_check(node.get_child_count() == 1 and node.get("screen_tip_label") == label, "连续提示复用同一层和标签，不叠加创建")
	_check(label.text == "装备栏已满", "最新操作提示替换旧提示")
	_check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "提示文字不拦截购买和施法鼠标")
	await process_frame
	_check(label.get_global_rect().position.x >= 0.0, "屏幕提示定位在可见范围")
	node.free()
	root.size = previous_size


func _check_upgrade_layout() -> void:
	var view: Control = _tool_panel("res://scenes/rest_period/shop_upgrade_button_view.tscn", "class_name ShopUpgradeButtonView") as Control
	view.size = Vector2(210, 230)
	view.call("display", 1, 2, 7, 1, true, true)
	for frame: int in range(4):
		await process_frame
	var price: Label = view.get_node("Margin/Content/Price") as Label
	var hint: Label = view.get_node("Margin/Content/Hint") as Label
	_check(price.text.contains("7") and hint.text.contains("再次点击"), "待确认时仍清楚显示费用与二次确认")
	_check(view.get_global_rect().encloses(hint.get_global_rect()), "确认文案在升级按钮内部，不与费用重叠")
	_check(view.get_combined_minimum_size().y <= 230.0, "升级视图适配原有按钮高度（实际最小尺寸%s）" % str(view.get_combined_minimum_size()))
	view.call("display", 1, 2, 7, 1, false, false)
	_check(price.modulate.g < 0.6 and hint.text == "金币不足", "买不起时费用标红且说明原因")
	view.call("display", 6, -1, 0, 0, false, false)
	_check(str(view.get_node("Margin/Content/Title").get("text")) == "商店已满级", "满级显示明确状态")
	_check(price.mouse_filter == Control.MOUSE_FILTER_IGNORE, "升级内容不抢父按钮点击")
	view.free()


func _check_inventory_feedback() -> void:
	var source: String = ""
	for method: String in ["on_mouse_right_bag_slot_button", "on_mouse_right_equipment_slot_button"]:
		source += _function_source("res://scripts/package_system/package_ui.gd", method) + "\n"
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar mouse_relic: Node\nvar equipment_locked: bool = false\nvar equipment_slots: Array = []\nvar messages: Array[String] = []\nfunc _find_first_empty_slot(_slots):\n\treturn null\nfunc _find_first_empty_unlocked_bag_slot():\n\treturn null\nfunc _can_equip_relic_to_slot(_relic, _slot) -> bool:\n\treturn true\nfunc _get_slot_button_relic(_slot):\n\treturn null\nfunc _show_screen_tip(message: String) -> void:\n\tmessages.append(message)\n" + source)
	var slot_script: GDScript = _fixture("@tool\nextends RefCounted\nfunc is_empty() -> bool:\n\treturn false\n")
	if script == null or slot_script == null:
		return
	var helper: RefCounted = script.new()
	var slot: RefCounted = slot_script.new()
	helper.call("on_mouse_right_bag_slot_button", slot)
	_check(str(helper.get("messages")[0]).contains("装备栏已满"), "右键穿戴无空位时明确说明")
	helper.call("on_mouse_right_equipment_slot_button", slot)
	_check(str(helper.get("messages")[1]).contains("背包没有可用空格"), "卸下无空位时明确说明")
	helper.set("equipment_locked", true)
	helper.call("on_mouse_right_bag_slot_button", slot)
	_check(str(helper.get("messages")[2]).contains("处于战斗中"), "保留战斗禁止穿戴的原有说明")


func _check_consumable_feedback() -> void:
	var source: String = _function_source("res://scripts/scenes/play_scene.gd", "_begin_or_use_equipped_consumable").replace("get_tree().paused", "paused").replace("FloatText", "notifier")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar player: Node\nvar paused: bool = false\nvar item: Relic\nvar consumable_cooldowns: RefCounted\nvar notifier: RefCounted\nvar uses: int = 0\nfunc _get_equipped_consumable_data() -> Dictionary:\n\treturn {\"relic\": item}\nfunc _get_consumable_aim_effect(_relic) -> Resource:\n\treturn null\nfunc _use_equipped_consumable() -> void:\n\tuses += 1\nfunc _begin_consumable_preview(_effect, _index) -> void:\n\tpass\n" + source)
	var state_script: GDScript = _fixture("@tool\nextends RefCounted\nvar remaining: float = 0.0\nvar messages: Array[String] = []\nfunc get_remaining(_item) -> float:\n\treturn remaining\nfunc show_action_tip(message: String, _key: String) -> void:\n\tmessages.append(message)\n")
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar is_dead: bool = false\nvar locked: bool = false\nfunc can_act() -> bool:\n\treturn not locked\n")
	if script == null or state_script == null or actor_script == null:
		return
	var helper: RefCounted = script.new()
	var state: RefCounted = state_script.new()
	var actor: Node = actor_script.new()
	helper.set("player", actor)
	helper.set("notifier", state)
	helper.set("consumable_cooldowns", state)
	helper.call("_begin_or_use_equipped_consumable")
	_check(str(state.get("messages")[0]).contains("尚未穿戴消耗品"), "未装备消耗品时按键不会静默失败")
	helper.set("item", (load("res://custom_resource/relic.gd") as GDScript).new())
	state.set("remaining", 2.5)
	helper.call("_begin_or_use_equipped_consumable")
	_check(str(state.get("messages")[1]).contains("冷却中"), "消耗品冷却期间说明等待时间")
	state.set("remaining", 0.0)
	actor.set("locked", true)
	helper.call("_begin_or_use_equipped_consumable")
	_check(str(state.get("messages")[2]).contains("无法行动"), "受控时说明不能使用消耗品")
	actor.set("locked", false)
	helper.call("_begin_or_use_equipped_consumable")
	_check(helper.get("uses") == 1, "反馈不会改变合法消耗品使用次数")
	actor.free()


func _check_shop_failures() -> void:
	if pipeline_script == null:
		return
	var material: Resource = (load("res://relics/level_1/003_树枝.tres") as Resource).duplicate(true)
	var data: Dictionary = _new_pipeline(material)
	var helper: RefCounted = data["helper"]
	data["shop"].get("current_slot")[0].set("item", material)
	data["stats"].set("gold", 0)
	helper.call("buy_relic", 0)
	_check(str(helper.get("feedback_messages")[0]).contains("金币不足"), "买不起商品时显示游戏内反馈")
	_check(data["shop"].get("current_slot")[0].get("item") == material, "购买失败不移除货架装备")
	data["stats"].set("gold", 10)
	for slot: Resource in data["build"].get("player_inventory").get("slots"):
		var filler: Resource = material.get_script().new()
		filler.set("id", "not_mergeable")
		slot.set("item", filler)
	helper.call("buy_relic", 0)
	_check(str(helper.get("feedback_messages")[1]).contains("背包已满"), "背包满时明确阻止购买")
	_check(data["stats"].get("gold") == 10, "背包满不会扣除金币")
	data["stats"].get("pending_free_relic_choice_levels").append(2)
	helper.call("_try_start_free_relic_choice")
	helper.call("set_reward_enabled", true)
	helper.call("buy_relic", 1)
	_check(str(helper.get("feedback_messages")[2]).contains("免费装备"), "免费奖励也有背包满提示")
	_check(helper.get("is_free_choice_active"), "背包满领取失败仍保留当前三选一")
	for node: Node in helper.get("shop_slots"):
		node.free()
	data["bus"].free()
