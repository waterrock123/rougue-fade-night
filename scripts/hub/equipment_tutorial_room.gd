class_name EquipmentTutorialRoom
extends TrainingRoom

const LESSONS: EquipmentTutorialCatalog = preload("res://custom_resource/equipment_tutorial_lessons.tres")
const PANEL: PackedScene = preload("res://scenes/hub/basic_tutorial_panel.tscn")
var lesson: EquipmentTutorialLesson
var tutorial_relic: Relic
var tutorial_panel: BasicTutorialPanel
var tutorial_shop: ShopController
var progress: EquipmentTutorialProgress = EquipmentTutorialProgress.new()
var baseline_stat: float = 0.0
var refresh_queued: bool = false


func _ready() -> void:
	enable_debug_console = false
	EventBus.is_battle_active = false
	super._ready()


func _create_training_player_build(startup: RunStartup) -> PlayerBuild:
	return TutorialBuildFactory.create_build(startup, null)


func _create_training_controls() -> void:
	debug_button.hide()
	pause_button.hide()
	tutorial_panel = PANEL.instantiate() as BasicTutorialPanel
	tutorial_panel.chapter_title = "装备入门"
	add_child(tutorial_panel)
	tutorial_panel.return_requested.connect(_return_to_hub)
	tutorial_panel.restart_requested.connect(restart_training)
	tutorial_panel.confirmation_requested.connect(_confirm_observation)


## 本章使用真实商店和构筑代理，不创建战斗、波次、假人或正式修整期奖励。
func _start_training_battle() -> void:
	lesson = LESSONS.resolve(run_stats.picked_character)
	if lesson == null or lesson.relic == null:
		tutorial_panel.show_step(run_stats.picked_character.character_name, 0, "教学配置需要补充", "缺少教学装备，请配置装备教学资源后重试。", "可以安全返回大厅。")
		return
	tutorial_relic = lesson.relic.duplicate(true) as Relic
	tutorial_relic.initialize_shop_price_reference()
	_configure_lesson_shop()
	if not _prepare_tutorial_items():
		tutorial_panel.show_step(run_stats.picked_character.character_name, 0, "教学配置需要补充", "请检查教学材料数量、可用格子与奖励配置。可以安全返回大厅。", "")
		return
	baseline_stat = _get_runtime_stats_controller().get_stat(lesson.stat_key)
	_connect_tutorial_signals()
	var rest: RestPeriod = (load(REST_SCENE_PATH) as PackedScene).instantiate() as RestPeriod
	rest.set_script(load("res://scripts/hub/tutorial_rest_period.gd"))
	rest.run_stats = run_stats
	tutorial_shop = rest.get_node("UILayer/Shop") as ShopController
	tutorial_shop.set_script(load(_get_tutorial_shop_script_path()))
	tutorial_shop.set("lesson_relic", tutorial_relic)
	tutorial_shop.run_stats = run_stats
	tutorial_shop.shop = run_stats.shop
	tutorial_shop.shop_config = run_stats.shop_config
	_configure_tutorial_shop()
	current_view.add_child(rest)
	package_ui.set_sell_context(null, null)
	_set_package_equipment_locked(false)
	_show_stage(_get_tutorial_stage())


## 只提供教学扩展点，装备入门的默认流程保持不变。
func _prepare_tutorial_items() -> bool:
	return true


func _get_tutorial_shop_script_path() -> String:
	return "res://scripts/hub/tutorial_shop_controller.gd"


func _configure_tutorial_shop() -> void:
	pass


func _get_tutorial_stage() -> int:
	return progress.stage


func _configure_lesson_shop() -> void:
	run_stats.shop = Shop.new()
	run_stats.shop.slot_count = 1
	run_stats.shop.shopkeeper = ShopKeeper.new()
	# 只借用原商人的外观，不复制整件货物池，也不抽取随机商品或对白。
	var keepers: Array[ShopKeeper] = run_stats.picked_character.shop_keeper_pool
	if not keepers.is_empty() and keepers[0] != null:
		run_stats.shop.shopkeeper.name = keepers[0].name
		run_stats.shop.shopkeeper.texture = keepers[0].texture
	run_stats.shop.shopkeeper.relic_pool = null
	run_stats.shop_config = ShopConfig.new()
	run_stats.set_gold(maxi(tutorial_relic.price, 0) + 3)


func _connect_tutorial_signals() -> void:
	progress.stage_changed.connect(_show_stage)
	progress.completed.connect(_on_tutorial_completed)
	EventBus.relic_purchased.connect(_on_relic_purchased)
	EventBus.equipment_update.connect(_request_progress_refresh)
	EventBus.inventory_update.connect(_request_progress_refresh)
	EventBus.attribute_update.connect(_request_progress_refresh)
	package_ui.visibility_changed.connect(_request_progress_refresh)


func _on_relic_purchased(relic: Relic) -> void:
	if relic != tutorial_relic:
		return
	progress.record_purchase(_contains_relic(run_stats.player_build.player_inventory.slots))
	_request_progress_refresh()


func _on_package_button_pressed() -> void:
	super._on_package_button_pressed()
	# 本章只展示装备、背包和属性，暂时收起未教学的技能与套装面板。
	skill_overview_panel.close_panel()
	tag_effect_ui.close_panel()
	_request_progress_refresh()


func _request_progress_refresh() -> void:
	if refresh_queued or not is_inside_tree():
		return
	refresh_queued = true
	call_deferred("_refresh_tutorial_progress")


## 库存、穿戴和属性可能在同一操作中连续变化，等本次真实操作完成后统一验证。
func _refresh_tutorial_progress() -> void:
	refresh_queued = false
	if lesson == null or not is_inside_tree():
		return
	if package_ui.visible:
		progress.record_bag_opened()
	progress.record_equipment(_is_lesson_equipped(), _is_stat_applied())
	if progress.stage == EquipmentTutorialProgress.Stage.OBSERVE:
		_update_observation()


func _contains_relic(slots: Array) -> bool:
	for slot: Slot in slots:
		if slot != null and slot.item == tutorial_relic:
			return true
	return false


func _is_lesson_equipped() -> bool:
	return _contains_relic(run_stats.player_build.player_equipment.equip_slots)


func _is_stat_applied() -> bool:
	var actual: float = _get_runtime_stats_controller().get_stat(lesson.stat_key)
	return actual >= baseline_stat + lesson.stat_increase - 0.001


func _confirm_observation() -> void:
	progress.confirm_observation(_is_lesson_equipped(), _is_stat_applied(), package_ui.visible and attributes_panel.visible)


func _show_stage(stage: int) -> void:
	var name: String = run_stats.picked_character.character_name
	match stage:
		EquipmentTutorialProgress.Stage.BUY:
			tutorial_panel.show_step(name, stage, "购买一件装备", "本章为%s准备了【%s】和教学金币。先点击商品，再点击一次确认购买。" % [name, tutorial_relic.relic_name], "购买只会把装备放入背包，不会自动穿戴。")
			tutorial_panel.set_focus_target(tutorial_shop.shop_slots[0])
		EquipmentTutorialProgress.Stage.OPEN_BAG:
			tutorial_panel.show_step(name, stage, "打开背包", "装备已经买到。点击上方的【背包】按钮，找到刚购买的【%s】。" % tutorial_relic.relic_name, "只是放在背包里，这件装备的穿戴加成还没有生效。")
			tutorial_panel.set_focus_target(package_button)
		EquipmentTutorialProgress.Stage.EQUIP:
			tutorial_panel.show_step(name, stage, "把装备穿戴到装备栏", "右键点击背包里的【%s】可自动穿戴；也可以左键拿起，再放进上方空装备格。" % tutorial_relic.relic_name, "卸下后会失去对应穿戴加成，可以重新穿上继续。")
			tutorial_panel.set_focus_target(package_ui.relic_container)
		EquipmentTutorialProgress.Stage.OBSERVE:
			tutorial_panel.show_step(name, stage, "查看属性变化", "装备已经生效。查看左侧属性面板的【%s】，确认穿戴前后的变化，再点击下方确认。" % lesson.stat_name, "背包用于存放，装备栏用于穿戴。")
			tutorial_panel.set_focus_target(_get_stat_row())
			_update_observation()
		EquipmentTutorialProgress.Stage.COMPLETE:
			tutorial_panel.show_step(name, stage, "已掌握装备入门", "你已完成购买、打开背包、穿戴和查看属性。可以继续练习卸下与穿戴，或返回大厅选择其他章节。", "教学装备与金币不会带出本章。")
			tutorial_panel.set_focus_target(null)


func _get_stat_row() -> Control:
	for row: AttributeUI in attributes_panel.attributes_ui:
		if row.attribute == lesson.stat_key:
			return row
	return attributes_panel


func _update_observation() -> void:
	var actual: float = _get_runtime_stats_controller().get_stat(lesson.stat_key)
	tutorial_panel.set_progress("%s：%s → %s（穿戴后 +%s）" % [lesson.stat_name, str(baseline_stat), str(actual), str(lesson.stat_increase)])
	tutorial_panel.set_confirmation("我看到了属性变化", package_ui.visible and attributes_panel.visible and _is_lesson_equipped() and _is_stat_applied())


func _on_tutorial_completed() -> void:
	if not ProfileManager.record_tutorial_chapter_completion(run_stats.picked_character.id, &"equipment"):
		tutorial_panel.set_progress("本章已完成，但进度写入失败；仍可正常退出。")


func _exit_tree() -> void:
	EventBus.is_battle_active = false
	super._exit_tree()
