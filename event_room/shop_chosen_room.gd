class_name ShopChosenRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "shop_chosen_room_event_buttons"
const CHOICE_COUNT := 3

var chosen_shopkeepers: Array[ShopKeeper] = []

@onready var desc_label: Label = $Label
@onready var shop_buttons: Array[EventRoomButton] = [
	$ShopButton3,
	$ShopButton2,
	$ShopButton4,
]


# 进入房间时从角色的商人池中稳定抽取几个候选商人，并把商人倾向写到按钮文案里。
func setup() -> void:
	chosen_shopkeepers = _roll_shopkeepers()
	_setup_shop_buttons()


# 根据本局种子和当前房间坐标创建局部随机，避免读档继续时同一个房间刷出不同商人。
func _roll_shopkeepers() -> Array[ShopKeeper]:
	var pool := _get_shopkeeper_pool()
	var result: Array[ShopKeeper] = []
	if pool.is_empty():
		return result

	var candidates := pool.duplicate()
	_shuffle_with_room_rng(candidates)
	for shopkeeper in candidates:
		if shopkeeper == null:
			continue
		result.append(shopkeeper)
		if result.size() >= CHOICE_COUNT:
			break

	return result


func _setup_shop_buttons() -> void:
	for index in range(shop_buttons.size()):
		var button := shop_buttons[index]
		if button == null:
			continue

		if index >= chosen_shopkeepers.size():
			button.hide()
			continue

		var shopkeeper := chosen_shopkeepers[index]
		_setup_shop_button(button, shopkeeper)

	if chosen_shopkeepers.is_empty():
		_set_desc_text("集市里空荡荡的，似乎今天没有商人在这里停留。")


# 单个按钮只保存“选择这个商人”的回调，展示文本则由商人资源实时生成。
func _setup_shop_button(button: EventRoomButton, shopkeeper: ShopKeeper) -> void:
	button.show()
	button.add_to_group(EVENT_BUTTON_GROUP)
	button.desc_text = "看向出售%s物品的商人" % _build_tag_desc(shopkeeper)
	button.detail_text = "下次进入修整期时商店商人替换为%s" % _get_shopkeeper_name(shopkeeper)
	button.pressed_desc = [_get_shopkeeper_pressed_desc(shopkeeper)]
	button.setup_button(_choose_shopkeeper.bind(shopkeeper, button))


# 选择商人后，替换本局商店的 shopkeeper。
# 冻结格子代表玩家想保留的商品，不能被换商人清掉；未冻结格子会在下次进商店时按新商人补货。
func _choose_shopkeeper(shopkeeper: ShopKeeper, button: EventRoomButton) -> void:
	if shopkeeper == null or run_stats == null or run_stats.shop == null:
		return

	run_stats.shop.shopkeeper = shopkeeper
	_clear_unfrozen_shop_slots_for_new_keeper()
	_set_desc_text(button.get_pressed_desc(0))
	_clear_event_buttons()


func _clear_unfrozen_shop_slots_for_new_keeper() -> void:
	var shop := run_stats.shop
	shop.ensure_slot_count()
	for slot_index in range(shop.current_slot.size()):
		if shop.is_slot_frozen(slot_index):
			continue

		var slot := shop.current_slot[slot_index]
		if slot != null:
			slot.item = null

	EventBus.shop_inventory_update.emit()


func _clear_event_buttons() -> void:
	for node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _get_shopkeeper_pool() -> Array[ShopKeeper]:
	if run_stats == null or run_stats.picked_character == null:
		return []

	var result: Array[ShopKeeper] = []
	for shopkeeper in run_stats.picked_character.shop_keeper_pool:
		if shopkeeper != null:
			result.append(shopkeeper)
	return result


func _shuffle_with_room_rng(array: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _build_room_seed()
	for index in range(array.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = array[index]
		array[index] = array[swap_index]
		array[swap_index] = temp


func _build_room_seed() -> int:
	var run := _get_run()
	var room := run.current_room if run != null else null
	var row := room.row if room != null else 0
	var column := room.column if room != null else 0
	var seed_text := "%s_shop_chosen_%s_%s" % [str(RunRng.seed_value), str(row), str(column)]
	return abs(seed_text.hash())


func _build_tag_desc(shopkeeper: ShopKeeper) -> String:
	if shopkeeper == null or shopkeeper.havetag.is_empty():
		return "杂货"

	var tag_names: Array[String] = []
	for tag in shopkeeper.havetag:
		if tag == null:
			continue
		tag_names.append(tag.tag_name)

	if tag_names.is_empty():
		return "杂货"
	return "、".join(tag_names)


func _get_shopkeeper_name(shopkeeper: ShopKeeper) -> String:
	if shopkeeper == null or shopkeeper.name.is_empty():
		return "未知商人"
	return shopkeeper.name


func _get_shopkeeper_pressed_desc(shopkeeper: ShopKeeper) -> String:
	if shopkeeper == null:
		return ""
	if shopkeeper.shop_desc.is_empty():
		return "你选择了%s，下一次修整期会由这位商人接待你。" % _get_shopkeeper_name(shopkeeper)
	return shopkeeper.shop_desc


func _set_desc_text(text: String) -> void:
	if desc_label != null:
		desc_label.text = text


func _get_run() -> Run:
	var node := get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
