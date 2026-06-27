class_name MushroomTruthRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "mushroom_truth_room_event_buttons"
const PROCESSED_RELIC_LEVEL := 2
const DEFAULT_SPECIAL_RELIC: Relic = preload("res://relics/special/202_孢子律动器.tres")
const DEFAULT_PROCESSED_TAG: RelicTag = preload("res://relic_tags/加工品tag.tres")
const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")

@export var special_relic: Relic = DEFAULT_SPECIAL_RELIC
@export var processed_tag: RelicTag = DEFAULT_PROCESSED_TAG
@export var processed_relic_level: int = PROCESSED_RELIC_LEVEL

@onready var relic_button: EventRoomButton = $RelicButton
@onready var refuse_button: EventRoomButton = $RefuseButton
@onready var desc_label: Label = $DescLabel


func setup() -> void:
	_setup_event_button(relic_button, _choose_special_relic)
	_setup_event_button(refuse_button, _choose_processed_relic)
	_refresh_button_availability()


func _setup_event_button(button: EventRoomButton, callback: Callable) -> void:
	if button == null:
		return

	button.add_to_group(EVENT_BUTTON_GROUP)
	button.setup_button(callback)


func _choose_special_relic() -> void:
	var used_fallback_reward := not _is_valid_reward_relic(special_relic)
	var reward := special_relic if not used_fallback_reward else _pick_processed_relic()
	if not _grant_relic(reward):
		_show_inventory_full_message()
		return

	if used_fallback_reward and desc_label != null:
		desc_label.text = "老人翻找了许久，似乎那件特殊样本还不稳定，于是先递给你一份加工过的补给。"
		_clear_event_buttons()
		_sync_run_after_choice()
		return

	_resolve_choice(relic_button, 0)


func _choose_processed_relic() -> void:
	var reward := _pick_processed_relic()
	if not _grant_relic(reward):
		_show_inventory_full_message()
		return

	_resolve_choice(refuse_button, 0)


func _resolve_choice(button: EventRoomButton, desc_index: int = 0) -> void:
	if button != null and desc_label != null:
		desc_label.text = button.get_pressed_desc(desc_index)

	_clear_event_buttons()
	_sync_run_after_choice()


func _clear_event_buttons() -> void:
	for node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _grant_relic(relic: Relic) -> bool:
	if not _is_valid_reward_relic(relic):
		return false
	if run_stats == null or run_stats.player_build == null:
		return false
	if not run_stats.player_build.can_accept_relic(relic):
		return false

	return run_stats.player_build.add_relic(relic.duplicate(true) as Relic)


func _pick_processed_relic() -> Relic:
	var candidates := _get_processed_relic_candidates()
	if candidates.is_empty():
		return null

	return _pick_weighted_relic(candidates)


func _get_processed_relic_candidates() -> Array[Relic]:
	var result: Array[Relic] = []
	var source_relics := _get_level_relics(processed_relic_level)

	for relic in source_relics:
		if not _is_valid_reward_relic(relic):
			continue
		if _relic_has_tag(relic, processed_tag):
			result.append(relic)

	return result


func _get_level_relics(relic_level: int) -> Array[Relic]:
	if run_stats != null and run_stats.shop != null and run_stats.shop.shopkeeper != null:
		return run_stats.shop.shopkeeper.get_available_relics_by_level(relic_level)

	if DEFAULT_RELIC_POOL != null:
		return DEFAULT_RELIC_POOL.get_relics_by_level(relic_level)

	return []


func _pick_weighted_relic(candidate_relics: Array[Relic]) -> Relic:
	var total_weight := 0.0
	var weighted_entries: Array[Dictionary] = []

	for relic in candidate_relics:
		if relic == null:
			continue

		var weight := _get_relic_roll_weight(relic)
		if weight <= 0.0:
			continue

		total_weight += weight
		weighted_entries.append({
			"relic": relic,
			"accumulated_weight": total_weight,
		})

	if weighted_entries.is_empty():
		return null

	var roll := RunRng.randf_range(0.0, total_weight)
	for entry in weighted_entries:
		if float(entry["accumulated_weight"]) >= roll:
			return entry["relic"] as Relic

	return weighted_entries.back()["relic"] as Relic


func _get_relic_roll_weight(relic: Relic) -> float:
	if relic == null:
		return 0.0
	if run_stats == null or run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return 1.0

	return run_stats.shop.shopkeeper.get_relic_base_weight(relic, 1.0)


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name:
			return true

	return false


func _is_valid_reward_relic(relic: Relic) -> bool:
	if relic == null:
		return false
	if relic.level <= 0:
		return false
	if relic.id.strip_edges().is_empty():
		return false
	if relic.relic_name.strip_edges().is_empty():
		return false
	if relic.icon == null:
		return false
	return true


func _refresh_button_availability() -> void:
	if relic_button == null:
		return

	# 特殊装备资源尚未填写完整时，不禁用按钮，而是明确提示并回退为加工品奖励，方便事件流程先跑通。
	if _is_valid_reward_relic(special_relic):
		return

	relic_button.detail_text = "特殊装备尚未配置完整；当前改为获得1件%s阶加工品" % str(processed_relic_level)
	relic_button.refresh_display()


func _show_inventory_full_message() -> void:
	if desc_label != null:
		desc_label.text = "你的背包已经装不下更多装备了。整理一下背包后，再来接受这份馈赠吧。"


func _sync_run_after_choice() -> void:
	var run := _get_run()
	if run == null:
		return

	if run.player_build_proxy != null and run_stats != null and run_stats.player_build != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
