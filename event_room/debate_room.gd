class_name DebateRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "debate_room_event_buttons"
const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
const PLAN_TAG: RelicTag = preload("res://relic_tags/计划tag.tres")
const INSIGHT_TAG: RelicTag = preload("res://relic_tags/洞察tag.tres")
const WEAPON_TAG: RelicTag = preload("res://relic_tags/凶器tag.tres")
const STRONG_ROBOT_SCENE: PackedScene = preload("res://entity/enemy/strong_robot.tscn")

@export var patient_robot_reward_tags: Array[RelicTag] = [PLAN_TAG, INSIGHT_TAG]
@export var attack_robot_reward_tags: Array[RelicTag] = [WEAPON_TAG]
@export var bounty_enemy_scene: PackedScene = STRONG_ROBOT_SCENE
@export var bounty_enemy_count: int = 2
@export var bounty_gold: int = 2

@onready var relic1_button: EventRoomButton = $Relic1Button
@onready var relic2_button: EventRoomButton = $Relic2Button
@onready var battle_button: EventRoomButton = $BattleButton
@onready var desc_label: Label = $DescLabel


func setup() -> void:
	_setup_event_button(relic1_button, _choose_patient_robot)
	_setup_event_button(relic2_button, _choose_attack_robot)
	_setup_event_button(battle_button, _choose_battle)


# 统一绑定按钮回调，并加入本房间按钮组，选择完成后可以一次性清理所有选项。
func _setup_event_button(button: EventRoomButton, callback: Callable) -> void:
	if button == null:
		return

	button.add_to_group(EVENT_BUTTON_GROUP)
	button.setup_button(callback)


func _choose_patient_robot() -> void:
	if not _grant_tagged_relic(patient_robot_reward_tags):
		_show_inventory_full_or_empty_message()
		return

	_resolve_choice(relic1_button)


func _choose_attack_robot() -> void:
	if not _grant_tagged_relic(attack_robot_reward_tags):
		_show_inventory_full_or_empty_message()
		return

	_resolve_choice(relic2_button)


func _choose_battle() -> void:
	if run_stats != null:
		run_stats.queue_bounty_enemy_for_next_battle(
			bounty_enemy_scene,
			bounty_enemy_count,
			bounty_gold,
			false
		)

	_resolve_choice(battle_button)


func _resolve_choice(button: EventRoomButton, desc_index: int = 0) -> void:
	if button != null and desc_label != null:
		desc_label.text = button.get_pressed_desc(desc_index)

	_clear_event_buttons()
	_sync_run_after_choice()


func _clear_event_buttons() -> void:
	for node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _grant_tagged_relic(tags: Array[RelicTag]) -> bool:
	if run_stats == null or run_stats.player_build == null:
		return false

	var reward: Relic = _pick_tagged_relic(tags)
	if reward == null:
		return false
	if not run_stats.player_build.can_accept_relic(reward):
		return false

	return run_stats.player_build.add_relic(reward.duplicate(true) as Relic)


func _pick_tagged_relic(tags: Array[RelicTag]) -> Relic:
	var candidates: Array[Relic] = _get_tagged_relic_candidates(tags)
	if candidates.is_empty():
		return null

	return _pick_weighted_relic(candidates)


func _get_tagged_relic_candidates(tags: Array[RelicTag]) -> Array[Relic]:
	var result: Array[Relic] = []
	for relic: Relic in _get_available_relics():
		if relic == null:
			continue
		if _relic_has_any_tag(relic, tags):
			result.append(relic)
	return result


# 奖励池优先沿用当前商人的货物池；如果此时没有商人数据，则回退到全局遗物池。
func _get_available_relics() -> Array[Relic]:
	var shop_level: int = 1
	if run_stats != null and run_stats.shop != null:
		shop_level = max(run_stats.shop.level, 1)
		if run_stats.shop.shopkeeper != null:
			return run_stats.shop.shopkeeper.get_available_relics(shop_level)

	if DEFAULT_RELIC_POOL != null:
		return DEFAULT_RELIC_POOL.get_relics_up_to_level(shop_level)

	return []


func _pick_weighted_relic(candidate_relics: Array[Relic]) -> Relic:
	var total_weight: float = 0.0
	var weighted_entries: Array[Dictionary] = []

	for relic: Relic in candidate_relics:
		var weight: float = _get_relic_roll_weight(relic)
		if weight <= 0.0:
			continue

		total_weight += weight
		weighted_entries.append({
			"relic": relic,
			"accumulated_weight": total_weight,
		})

	if weighted_entries.is_empty():
		return null

	var roll: float = RunRng.randf_range(0.0, total_weight)
	for entry: Dictionary in weighted_entries:
		if float(entry["accumulated_weight"]) >= roll:
			return entry["relic"] as Relic

	return weighted_entries.back()["relic"] as Relic


# 保留商人货物基础权重，并叠加商人偏好标签，让事件奖励和商店风格保持一致。
func _get_relic_roll_weight(relic: Relic) -> float:
	if relic == null:
		return 0.0

	var weight: float = 1.0
	var shopkeeper: ShopKeeper = null
	if run_stats != null and run_stats.shop != null:
		shopkeeper = run_stats.shop.shopkeeper

	if shopkeeper == null:
		return weight

	weight = shopkeeper.get_relic_base_weight(relic, 1.0)
	for preferred_tag: RelicTag in shopkeeper.havetag:
		if preferred_tag != null and _relic_has_tag(relic, preferred_tag):
			weight += shopkeeper.preferred_tag_weight_bonus

	return max(weight, 0.0)


func _relic_has_any_tag(relic: Relic, target_tags: Array[RelicTag]) -> bool:
	for target_tag: RelicTag in target_tags:
		if _relic_has_tag(relic, target_tag):
			return true
	return false


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag: RelicTag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name:
			return true

	return false


func _show_inventory_full_or_empty_message() -> void:
	if desc_label == null:
		return

	desc_label.text = "你暂时无法获得这份奖励：可能是背包已经满了，也可能是当前遗物池中没有符合标签的装备。"


func _sync_run_after_choice() -> void:
	var run: Run = _get_run()
	if run == null:
		return

	# 事件奖励可能改变 PlayerBuild，需要让 Run 常驻代理重新绑定，方便背包/属性面板立即看到变化。
	if run.player_build_proxy != null and run_stats != null and run_stats.player_build != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


func _get_run() -> Run:
	var node: Node = get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
