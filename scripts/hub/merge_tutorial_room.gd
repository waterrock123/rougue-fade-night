class_name MergeTutorialRoom
extends EquipmentTutorialRoom

const MERGE_CONFIG: MergeTutorialConfig = preload("res://custom_resource/merge_tutorial_config.tres")
var merge_progress: MergeTutorialProgress = MergeTutorialProgress.new()
var merge_candidate: Relic
var upgraded_relic: Relic
var reward_level: int = -1


func _create_training_controls() -> void:
	super._create_training_controls()
	tutorial_panel.chapter_title = "装备合成与免费三选一"


func _start_training_battle() -> void:
	super._start_training_battle()
	if is_instance_valid(tutorial_shop) and not package_ui.visible:
		_on_package_button_pressed()


func _configure_lesson_shop() -> void:
	super._configure_lesson_shop()
	run_stats.shop.level = MERGE_CONFIG.shop_level
	run_stats.shop.slot_count = 3


func _prepare_tutorial_items() -> bool:
	if not MERGE_CONFIG.is_valid_for_lesson() or tutorial_relic.leveltip != Relic.LevelTip.UNLEVELUP:
		return false
	if not TutorialMergeMaterials.seed(run_stats.player_build, tutorial_relic):
		return false
	# 先应用预置穿戴的那一件，保留真实穿戴加成；不触发普通获得或合成事件。
	player_build_proxy.bind_player_build(run_stats.player_build)
	return true


func _get_tutorial_shop_script_path() -> String:
	return "res://scripts/hub/merge_tutorial_shop.gd"


func _configure_tutorial_shop() -> void:
	tutorial_shop.set("tutorial_config", MERGE_CONFIG)
	tutorial_shop.connect("tutorial_shop_changed", _request_progress_refresh)


func _get_tutorial_stage() -> int:
	return merge_progress.stage


func _connect_tutorial_signals() -> void:
	merge_progress.stage_changed.connect(_show_stage)
	merge_progress.completed.connect(_on_tutorial_completed)
	EventBus.relic_upgraded.connect(_on_tutorial_relic_upgraded)
	EventBus.relic_merged_to_levelup.connect(_on_tutorial_merge)
	EventBus.relic_purchased.connect(_on_relic_purchased)
	EventBus.equipment_update.connect(_request_progress_refresh)
	EventBus.inventory_update.connect(_request_progress_refresh)
	package_ui.visibility_changed.connect(_request_progress_refresh)


func _on_tutorial_relic_upgraded(relic: Relic, receiver: PlayerBuild) -> void:
	if receiver == run_stats.player_build and relic != null and relic.id == tutorial_relic.id:
		merge_candidate = relic


## 同时要求接收者匹配和真正的合成事件，直接获得升级态装备不能冒领三选一。
func _on_tutorial_merge(relic: Relic) -> void:
	if merge_progress.stage != MergeTutorialProgress.Stage.BUY or upgraded_relic != null or relic != merge_candidate:
		return
	if relic == null or relic.level != tutorial_relic.level or not _valid_merge_result():
		return
	upgraded_relic = relic
	merge_progress.record_merge(true)
	reward_level = run_stats.get_free_relic_choice_level_for_now()
	run_stats.queue_free_relic_choice(reward_level)
	_request_progress_refresh()


func _on_relic_purchased(relic: Relic) -> void:
	if relic == tutorial_relic:
		merge_progress.record_purchase(true)
	_request_progress_refresh()


func _valid_merge_result() -> bool:
	var build: PlayerBuild = run_stats.player_build
	return TutorialMergeMaterials.count(build, tutorial_relic.id, true) == 1 and TutorialMergeMaterials.count(build, tutorial_relic.id, false) == 0


func _refresh_tutorial_progress() -> void:
	refresh_queued = false
	if not is_instance_valid(tutorial_shop) or not is_inside_tree():
		return
	# 材料拿在鼠标上时可能暂时凑不齐；放回背包或装备栏后继续走真实跨栏合成。
	if merge_progress.stage == MergeTutorialProgress.Stage.BUY:
		run_stats.player_build.check_relic_merges()
	if merge_progress.stage == MergeTutorialProgress.Stage.OBSERVE:
		tutorial_panel.set_focus_target(_upgraded_target() if package_ui.visible else package_button)
		tutorial_panel.set_confirmation("我看到了升级效果，继续领奖", _valid_merge_result() and _choice_ready() and package_ui.visible)
	elif merge_progress.stage == MergeTutorialProgress.Stage.CHOOSE:
		var reward: Relic = tutorial_shop.get("selected_reward") as Relic
		var owned: bool = reward != null and _owns_reward(reward)
		merge_progress.record_reward(owned, bool(tutorial_shop.get("reward_was_free")), _shelf_restored())
	elif merge_progress.stage == MergeTutorialProgress.Stage.RESTORED:
		tutorial_panel.set_confirmation("确认货架已恢复，完成本章", _shelf_restored())


func _choice_ready() -> bool:
	if not tutorial_shop.is_free_choice_active or tutorial_shop.free_choice_level != reward_level:
		return false
	if tutorial_shop.free_choice_slot_indices.size() != 3:
		return false
	for index: int in tutorial_shop.free_choice_slot_indices:
		var relic: Relic = run_stats.shop.current_slot[index].item
		if relic == null or relic.price != 0 or relic.level != reward_level:
			return false
	return true


func _shelf_restored() -> bool:
	return bool(tutorial_shop.call("has_restored_shelf")) and run_stats.pending_free_relic_choice_levels.is_empty()


func _owns_reward(reward: Relic) -> bool:
	for slots: Array in [run_stats.player_build.player_inventory.slots, run_stats.player_build.player_equipment.equip_slots]:
		for slot: Slot in slots:
			if slot != null and slot.item == reward:
				return true
	return false


func _upgraded_target() -> Control:
	for button: Control in package_ui.equipment_slots + package_ui.bag_slots:
		if button.has_method("_get_slot_relic_data") and button.call("_get_slot_relic_data") == upgraded_relic:
			return button
	return package_ui.relic_container


func _confirm_observation() -> void:
	if merge_progress.stage == MergeTutorialProgress.Stage.OBSERVE:
		merge_progress.confirm_upgrade(_valid_merge_result(), _choice_ready(), package_ui.visible)
	elif merge_progress.stage == MergeTutorialProgress.Stage.RESTORED:
		merge_progress.confirm_restored(_shelf_restored())


func _show_stage(stage: int) -> void:
	var name: String = run_stats.picked_character.character_name
	match stage:
		MergeTutorialProgress.Stage.BUY:
			var count: int = maxi(tutorial_relic.upgrade_merge_count, 2)
			tutorial_panel.show_step(name, stage, "买下最后一件，触发合成", "已准备%d件【%s】：1件在装备栏，%d件在背包。点击货架上的同款，再点击一次购买；集齐%d件会自动合成。" % [count - 1, tutorial_relic.relic_name, count - 2, count], "装备栏与背包里的同名未升级装备一起参与。")
			tutorial_panel.set_focus_target(tutorial_shop.shop_slots[0])
		MergeTutorialProgress.Stage.OBSERVE:
			tutorial_panel.show_step(name, stage, "查看合成后的升级态", "材料已合成，只剩1件升级态【%s】。把鼠标移到高亮装备上，查看新增的升级效果。" % tutorial_relic.relic_name, "升级态会开启额外效果，但装备的等阶仍为Lv.%d，不是等阶+1。" % tutorial_relic.level)
			_request_progress_refresh()
		MergeTutorialProgress.Stage.CHOOSE:
			tutorial_panel.show_step(name, stage, "领取一次免费三选一", "这次合成获得一次免费奖励。三个商品都为Lv.%d，价格均为0；选中任意一个后再次点击领取。" % reward_level, "奖励等阶在合成时按商店等级+1确定；只能领取一件。")
			tutorial_shop.call("set_reward_enabled", true)
			tutorial_panel.set_focus_target(tutorial_shop.equip_container)
		MergeTutorialProgress.Stage.RESTORED:
			var names: Array[String] = []
			for stock: Resource in MERGE_CONFIG.ordinary_extras:
				names.append(str(stock.get("relic_name")))
			tutorial_panel.show_step(name, stage, "确认商店恢复原货架", "免费装备已入包，没有扣除金币。三选一已退出，【%s】和普通售价重新显示；已买走的材料格保持空位。" % "、".join(names), "免费三选一是一次临时奖励，不会永久替换普通货架。")
			tutorial_panel.set_focus_target(tutorial_shop.equip_container)
			tutorial_panel.set_confirmation("确认货架已恢复，完成本章", _shelf_restored())
		MergeTutorialProgress.Stage.COMPLETE:
			tutorial_panel.show_step(name, stage, "已掌握合成与免费奖励", "你已完成跨背包与装备栏合成、查看升级态、免费三选一和恢复货架。可以重新练习，或返回大厅选择其他章节。", "教学装备、金币和奖励均不会带出本章。")
			tutorial_panel.set_focus_target(null)


func _on_tutorial_completed() -> void:
	if not ProfileManager.record_tutorial_chapter_completion(run_stats.picked_character.id, &"merge"):
		tutorial_panel.set_progress("本章已完成，但进度写入失败；仍可正常退出。")
