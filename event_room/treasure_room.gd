class_name TreasureRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "treasure_room_event_buttons"
const GOLD_REWARD := 6
const EQUIPMENT_REWARD_COUNT := 2
const ALL_CHOICE_BAD_CHANCE := 0.7
const SPEED_LOSS := 4
const LUCK_PER_BONUS_DIE := 3

@onready var gold_button: EventRoomButton = $GoldButton
@onready var equip_button: EventRoomButton = $EquipButton
@onready var all_button: EventRoomButton = $AllButton
@onready var label: Label = _find_desc_label()


func setup() -> void:
	_setup_event_button(gold_button, _choose_gold)
	_setup_event_button(equip_button, _choose_equipment)
	_setup_event_button(all_button, _choose_all)


# 给按钮绑定回调，并加入宝物房按钮组，方便选择后统一清理所有选项。
func _setup_event_button(button: EventRoomButton, callback: Callable) -> void:
	if button == null:
		return

	button.add_to_group(EVENT_BUTTON_GROUP)
	button.setup_button(callback)


func _choose_gold() -> void:
	_grant_gold(GOLD_REWARD)
	_resolve_choice(gold_button, 0)


func _choose_equipment() -> void:
	_grant_random_relics(EQUIPMENT_REWARD_COUNT)
	_resolve_choice(equip_button, 0)


func _choose_all() -> void:
	_grant_gold(GOLD_REWARD)
	_grant_random_relics(EQUIPMENT_REWARD_COUNT)

	var avoided_penalty := _roll_avoid_penalty(ALL_CHOICE_BAD_CHANCE)
	if not avoided_penalty:
		_lose_speed(SPEED_LOSS)

	# pressed_desc[0] 是幸运避开惩罚的描述，pressed_desc[1] 是失去速度的描述。
	var desc_index := 0 if avoided_penalty else 1
	_resolve_choice(all_button, desc_index)


func _resolve_choice(button: EventRoomButton, desc_index: int) -> void:
	if button != null and label != null:
		label.text = button.get_pressed_desc(desc_index)

	_clear_event_buttons()
	_sync_run_after_choice()


func _clear_event_buttons() -> void:
	for node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _grant_gold(amount: int) -> void:
	if run_stats == null:
		return

	run_stats.set_gold(run_stats.gold + max(amount, 0))


func _grant_random_relics(count: int) -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates := _get_available_relics()
	if candidates.is_empty():
		return

	for _index in range(count):
		var relic := _pick_weighted_relic(candidates)
		if relic == null:
			continue
		run_stats.player_build.add_relic(relic.duplicate(true) as Relic)


# 只从本局商人的货物池中抽取，且装备等级不高于当前商店等级。
func _get_available_relics() -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats == null or run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	var max_level = max(run_stats.shop.level, 1)
	for relic in run_stats.shop.shopkeeper.relics:
		if relic != null and relic.level <= max_level:
			result.append(relic)

	return result


# 宝物房沿用商人偏好标签的权重，保证“从当前商人那里 roll 装备”的体验和商店接近。
func _pick_weighted_relic(candidate_relics: Array[Relic]) -> Relic:
	var total_weight := 0.0
	var weighted_entries: Array[Dictionary] = []

	for relic in candidate_relics:
		var weight := _get_relic_roll_weight(relic)
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

	var weight := 1.0
	var shopkeeper := run_stats.shop.shopkeeper if run_stats != null and run_stats.shop != null else null
	if shopkeeper == null:
		return weight

	for preferred_tag in shopkeeper.havetag:
		if preferred_tag != null and _relic_has_tag(relic, preferred_tag):
			weight += 2.0

	return weight


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for tag in relic.tags:
		if tag == null:
			continue
		if tag == target_tag or tag.tag_name == target_tag.tag_name:
			return true

	return false


# 负面概率判定：幸运会提供额外奖励骰，只要任意一次避开负面，就采用最好的结果。
func _roll_avoid_penalty(bad_chance: float) -> bool:
	var roll_count := 1 + _get_bonus_dice_count()
	for _roll_index in range(roll_count):
		if RunRng.randf() >= bad_chance:
			return true

	return false


# 暂定每 3 点幸运提供 1 个奖励骰，后续如果需要可以把这个常量移动到资源配置里。
func _get_bonus_dice_count() -> int:
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_stats == null:
		return 0

	var luck = max(run_stats.player_build.player_stats.luck, 0)
	return int(floor(float(luck) / float(LUCK_PER_BONUS_DIE)))


func _lose_speed(amount: int) -> void:
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_stats == null:
		return

	var stats_data := run_stats.player_build.player_stats
	stats_data.speed = max(stats_data.speed - amount, 0)
	EventBus.attribute_update.emit()


func _sync_run_after_choice() -> void:
	var run := _get_run()
	if run == null:
		return

	# 事件可能直接修改 PlayerBuild 的初始数据，需要让常驻代理重新绑定一次，属性面板才会立即看到新结果。
	if run.player_build_proxy != null and run_stats != null and run_stats.player_build != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


func _find_desc_label() -> Label:
	var desc_label := get_node_or_null("DescLabel") as Label
	if desc_label != null:
		return desc_label
	return get_node_or_null("Label") as Label


func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null
	

func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
