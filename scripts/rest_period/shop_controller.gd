class_name ShopController
extends Control

@export var run_stats: RunStats
@export var shop_config: ShopConfig
@export var shop: Shop

@onready var equip_container: HBoxContainer = %EquipContainer
@onready var refresh_button: Button = %RefreshButton
@onready var freeze_button: Button = %FrezeButton
@onready var level_up_button: Button = %LevelUpButton
@onready var refresh_cost_label: Label = %RefreshCost
@onready var level_up_cost_label: Label = %LevelUpNumber
@onready var money_token: ShopKeeperUI = $VBoxContainer/BuyContainer/ShowContainer/MoneyToken

var shop_slots: Array[ShopEquipButton] = []
var shop_button_scene := preload("res://scenes/rest_period/shop_equip_button.tscn")
const FREE_CHOICE_SLOT_COUNT := 3

var is_free_choice_active: bool = false
var free_choice_level: int = -1
var free_choice_slot_indices: Array[int] = []
var saved_shop_slots: Array[Slot] = []
var saved_frozen_slots: Array[bool] = []
var suppress_free_choice_start: bool = false


func _ready() -> void:
	_bind_runtime_data()
	_connect_signals()
	_initialize_shop()


# 允许运行时从外部重新绑定修整期共享数据。
func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	_bind_runtime_data()
	_update_shop_ui()


# 允许外部把本局共享的商店状态和配置绑定进来。
# 这里不 duplicate，目的是让修整期里对商店的修改直接沉淀到 RunStats 中。
func bind_shop_runtime(new_shop: Shop, new_shop_config: ShopConfig) -> void:
	shop = new_shop
	shop_config = new_shop_config
	_bind_runtime_data()
	_initialize_shop()


# 离开修整期时恢复真实商店状态，避免临时三选一覆盖态被保存到下一次修整期。
func cancel_free_choice_state() -> void:
	_end_free_relic_choice(false)


# 进入商店时初始化数据、按钮数量和商品内容。
func _initialize_shop() -> void:
	if shop == null or shop_config == null:
		return

	shop.ensure_slot_count()
	_rebuild_shop_buttons()
	_roll_slots(0)
	_sync_shop_ui()
	_update_shop_ui()
	_try_start_free_relic_choice()


# 左键双击升级按钮时，提升商店等级并应用该等级配置的效果。
# 如果升级带来了额外槽位，只给新增槽位补货，不刷新旧商品。
func level_up() -> void:
	if shop == null or shop_config == null or run_stats == null:
		return

	var next_level := shop.level + 1
	var data := get_level_data(next_level)
	if data == null:
		return

	if run_stats.gold < data.upgrade_cost:
		push_warning("Not enough gold to level up shop.")
		return

	var previous_slot_count := shop.slot_count
	run_stats.set_gold(run_stats.gold - data.upgrade_cost)
	shop.level = next_level

	for effect in data.effects:
		if effect != null:
			effect.apply(shop)

	shop.ensure_slot_count()

	if shop.slot_count != previous_slot_count:
		_rebuild_shop_buttons()
		_roll_slots(previous_slot_count)
		_sync_shop_ui()

	_update_shop_ui()


func get_level_data(level: int) -> ShopLevelData:
	for data in shop_config.level_data:
		if data.level == level:
			return data
	return null


# 手动刷新商店商品。
# 主动刷新优先级高于冻结：会先解除所有冻结，再重新生成商品。
func refresh() -> void:
	if shop == null or shop.shopkeeper == null or run_stats == null:
		return

	var refresh_cost := _get_refresh_cost()
	if run_stats.gold < refresh_cost:
		push_warning("Not enough gold to refresh shop.")
		return

	run_stats.set_gold(run_stats.gold - refresh_cost)

	if is_free_choice_active:
		_end_free_relic_choice(false)

	shop.clear_all_frozen()
	_roll_slots(0)
	_sync_shop_ui()
	_update_shop_ui()
	_try_start_free_relic_choice()


# 切换所有商店商品的冻结状态。
func frezee() -> void:
	if shop == null or shop_slots.is_empty():
		return

	if is_free_choice_active:
		AudioController.play_ui_sound(&"lock_item")
		_toggle_free_choice_visual_freeze()
		return

	# 只让有商品的格子参与冻结判断，避免买空的格子把整体状态卡死。
	var has_filled_slot := false
	var should_freeze := false
	for slot_button in shop_slots:
		if slot_button.is_empty():
			continue

		has_filled_slot = true
		if not slot_button.is_frozen:
			should_freeze = true
			break

	if not has_filled_slot:
		return

	AudioController.play_ui_sound(&"lock_item")
	for slot_button in shop_slots:
		if not slot_button.is_empty():
			slot_button.set_frozen(should_freeze)
			shop.set_slot_frozen(slot_button.slot_index, should_freeze)


# 处理购买逻辑：双击商品格购买，并将遗物塞进库存的第一个空位。
func buy_relic(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop.current_slot.size():
		return

	if is_free_choice_active:
		_buy_free_choice_relic(slot_index)
		return

	var player_build := _get_player_build()
	if run_stats == null or player_build == null:
		return

	var slot_ := shop.current_slot[slot_index]
	if slot_ == null or slot_.item == null:
		return

	var relic := slot_.item
	if run_stats.gold < relic.price:
		push_warning("Not enough gold to buy relic: %s" % relic.relic_name)
		return
	if not player_build.can_accept_relic(relic):
		push_warning("Inventory is full, cannot buy relic: %s" % relic.relic_name)
		return

	run_stats.set_gold(run_stats.gold - relic.price)
	suppress_free_choice_start = true
	EventBus.buy_equipment.emit(relic)
	suppress_free_choice_start = false
	slot_.item = null
	shop.set_slot_frozen(slot_index, false)

	var slot_button := shop_slots[slot_index]
	slot_button.set_frozen(false)
	slot_button.clear_relic()
	_update_shop_ui()
	_try_start_free_relic_choice()


func _on_buy_equipment(relic: Relic) -> void:
	var player_build := _get_player_build()
	if run_stats == null or player_build == null:
		return

	var success := player_build.add_relic(relic)
	if not success:
		push_warning("Inventory is full, failed to add relic: %s" % relic.relic_name)


func _on_refresh_button_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		refresh()


func _on_freeze_button_gui_input(event: InputEvent) -> void:
	if _is_left_click(event):
		frezee()


func _on_level_up_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
			level_up()


func _connect_signals() -> void:
	if not EventBus.buy_equipment.is_connected(_on_buy_equipment):
		EventBus.buy_equipment.connect(_on_buy_equipment)

	if not EventBus.gold_changed.is_connected(_update_shop_ui):
		EventBus.gold_changed.connect(_update_shop_ui)

	if not refresh_button.gui_input.is_connected(_on_refresh_button_gui_input):
		refresh_button.gui_input.connect(_on_refresh_button_gui_input)

	if not freeze_button.gui_input.is_connected(_on_freeze_button_gui_input):
		freeze_button.gui_input.connect(_on_freeze_button_gui_input)

	if not level_up_button.gui_input.is_connected(_on_level_up_button_gui_input):
		level_up_button.gui_input.connect(_on_level_up_button_gui_input)

	if not EventBus.free_relic_choice_changed.is_connected(_on_free_relic_choice_changed):
		EventBus.free_relic_choice_changed.connect(_on_free_relic_choice_changed)


# 把运行时数据绑定给 UI 子节点。
func _bind_runtime_data() -> void:
	if money_token != null:
		money_token.run_stats = run_stats
		money_token.shop = shop


# 按照 shop.slot_count 重建可售卖按钮数量。
func _rebuild_shop_buttons() -> void:
	for child in equip_container.get_children():
		equip_container.remove_child(child)
		child.queue_free()

	shop_slots.clear()

	for slot_index in range(shop.slot_count):
		var slot_button := shop_button_scene.instantiate() as ShopEquipButton
		slot_button.slot_index = slot_index
		slot_button.purchase_requested.connect(buy_relic)
		equip_container.add_child(slot_button)
		shop_slots.append(slot_button)

	_sync_shop_ui()


# 把 Shop.current_slot 的数据同步到每个按钮上。
func _sync_shop_ui() -> void:
	if shop == null:
		return

	for slot_index in range(min(shop_slots.size(), shop.current_slot.size())):
		var slot_ := shop.current_slot[slot_index]
		if slot_ == null:
			slot_ = Slot.new()
			shop.current_slot[slot_index] = slot_

		shop_slots[slot_index].set_slot(slot_)
		shop_slots[slot_index].set_frozen(shop.is_slot_frozen(slot_index))


# 把指定范围内的格子重新随机补货。
# start_index 可用于升级扩槽时只处理新增格子。
func _roll_slots(start_index: int) -> void:
	if shop == null or shop.shopkeeper == null:
		return

	shop.ensure_slot_count()
	var candidate_relics := _get_available_relics()
	if candidate_relics.is_empty():
		return

	for slot_index in range(start_index, shop.slot_count):
		var slot_ := shop.current_slot[slot_index]
		if slot_ == null:
			slot_ = Slot.new()
			shop.current_slot[slot_index] = slot_

		if shop.is_slot_frozen(slot_index):
			continue

		slot_.item = _pick_random_relic(candidate_relics)


func _update_shop_ui() -> void:
	if money_token != null:
		money_token.updata_ui()

	if refresh_cost_label != null:
		refresh_cost_label.text = str(_get_refresh_cost())

	if level_up_cost_label != null:
		var next_level_data := get_level_data(shop.level + 1) if shop != null else null
		if next_level_data == null:
			level_up_cost_label.text = "--"
		else:
			level_up_cost_label.text = str(next_level_data.upgrade_cost)


func _get_available_relics() -> Array[Relic]:
	var result: Array[Relic] = []
	if shop == null or shop.shopkeeper == null:
		return result

	for relic in shop.shopkeeper.relics:
		if relic != null and relic.level <= shop.level:
			result.append(relic)

	return result


func _pick_random_relic(candidate_relics: Array[Relic]) -> Relic:
	if candidate_relics.is_empty():
		return null

	var relic: Relic = candidate_relics.pick_random()
	if relic == null:
		return null

	return relic.duplicate(true) as Relic


func _on_free_relic_choice_changed() -> void:
	_try_start_free_relic_choice()


# 如果存在待消费机会，切入一次免费装备三选一。
func _try_start_free_relic_choice() -> void:
	if suppress_free_choice_start or is_free_choice_active or run_stats == null or shop == null:
		return
	if not run_stats.has_free_relic_choice():
		return

	var choice_level := run_stats.pop_free_relic_choice_level()
	if choice_level < 0:
		return

	_begin_free_relic_choice(choice_level)


func _begin_free_relic_choice(choice_level: int) -> void:
	_save_shop_state()
	is_free_choice_active = true
	free_choice_level = choice_level

	shop.ensure_slot_count()
	_clear_shop_slots_for_free_choice()
	if not _roll_free_choice_slots(choice_level):
		_end_free_relic_choice(true)
		return
	_sync_shop_ui()
	_update_shop_ui()


# 结束当前三选一。consume_next 为 true 时，会继续消费队列里的下一次机会。
func _end_free_relic_choice(consume_next: bool = true) -> void:
	if not is_free_choice_active:
		return

	is_free_choice_active = false
	free_choice_level = -1
	free_choice_slot_indices.clear()
	_restore_shop_state()
	_sync_shop_ui()
	_update_shop_ui()

	if consume_next:
		_try_start_free_relic_choice()


func _buy_free_choice_relic(slot_index: int) -> void:
	if not free_choice_slot_indices.has(slot_index):
		return

	var player_build := _get_player_build()
	if player_build == null:
		return

	var slot_ := shop.current_slot[slot_index]
	if slot_ == null or slot_.item == null:
		return

	var relic := slot_.item
	if not player_build.can_accept_relic(relic):
		push_warning("Inventory is full, cannot take free relic: %s" % relic.relic_name)
		return

	EventBus.buy_equipment.emit(relic)
	_end_free_relic_choice(true)


func _save_shop_state() -> void:
	saved_shop_slots = _duplicate_slot_array(shop.current_slot)
	saved_frozen_slots = _duplicate_bool_array(shop.frozen_slots)


func _restore_shop_state() -> void:
	shop.current_slot = _duplicate_slot_array(saved_shop_slots)
	shop.frozen_slots = _duplicate_bool_array(saved_frozen_slots)
	shop.ensure_slot_count()
	saved_shop_slots.clear()
	saved_frozen_slots.clear()


func _duplicate_slot_array(source_slots: Array[Slot]) -> Array[Slot]:
	var result: Array[Slot] = []
	for slot_ in source_slots:
		if slot_ == null:
			result.append(Slot.new())
		else:
			result.append(slot_.duplicate(true) as Slot)
	return result


func _duplicate_bool_array(source_values: Array[bool]) -> Array[bool]:
	var result: Array[bool] = []
	for value in source_values:
		result.append(bool(value))
	return result


func _clear_shop_slots_for_free_choice() -> void:
	shop.clear_all_frozen()
	for slot_index in range(shop.current_slot.size()):
		var slot_ := shop.current_slot[slot_index]
		if slot_ == null:
			slot_ = Slot.new()
			shop.current_slot[slot_index] = slot_
		slot_.item = null


func _roll_free_choice_slots(choice_level: int) -> bool:
	free_choice_slot_indices.clear()
	var slot_count = min(FREE_CHOICE_SLOT_COUNT, shop.slot_count)
	if slot_count <= 0:
		return false

	var start_index := 0
	if shop.slot_count > slot_count:
		start_index = randi_range(0, shop.slot_count - slot_count)

	var candidate_relics := _get_available_relics_by_level(choice_level)
	if candidate_relics.is_empty():
		candidate_relics = _get_available_relics()
	if candidate_relics.is_empty():
		return false

	for offset in range(slot_count):
		var slot_index := start_index + offset
		var slot_ := shop.current_slot[slot_index]
		var relic := _pick_random_relic(candidate_relics)
		if relic == null:
			continue

		relic.price = 0
		slot_.item = relic
		free_choice_slot_indices.append(slot_index)

	return not free_choice_slot_indices.is_empty()


func _get_available_relics_by_level(relic_level: int) -> Array[Relic]:
	var result: Array[Relic] = []
	if shop == null or shop.shopkeeper == null:
		return result

	for relic in shop.shopkeeper.relics:
		if relic != null and relic.level == relic_level:
			result.append(relic)

	return result


# 三选一状态下的冻结只是视觉提示，不写入 Shop.frozen_slots，因此不会跨修整期保存。
func _toggle_free_choice_visual_freeze() -> void:
	var should_freeze := false
	for slot_index in free_choice_slot_indices:
		if slot_index < 0 or slot_index >= shop_slots.size():
			continue
		if not shop_slots[slot_index].is_frozen:
			should_freeze = true
			break

	for slot_index in free_choice_slot_indices:
		if slot_index < 0 or slot_index >= shop_slots.size():
			continue
		shop_slots[slot_index].set_frozen(should_freeze)


func _get_refresh_cost() -> int:
	if shop_config == null:
		return 0
	return max(shop_config.refresh_cost, 0)


func _get_player_inventory() -> Inventory:
	if run_stats == null or run_stats.player_build == null:
		return null

	return run_stats.player_build.player_inventory


func _get_player_build() -> PlayerBuild:
	if run_stats == null:
		return null
	return run_stats.player_build


func _is_left_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	return false
