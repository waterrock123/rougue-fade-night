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


# 进入商店时初始化数据、按钮数量和商品内容。
func _initialize_shop() -> void:
	if shop == null or shop_config == null:
		return

	shop.ensure_slot_count()
	_rebuild_shop_buttons()
	_roll_slots(0)
	_sync_shop_ui()
	_update_shop_ui()


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
# 被冻结的格子保留原商品，其余格子从 shopkeeper 商品池中随机填充。
func refresh() -> void:
	if shop == null or shop.shopkeeper == null or run_stats == null:
		return

	var refresh_cost := _get_refresh_cost()
	if run_stats.gold < refresh_cost:
		push_warning("Not enough gold to refresh shop.")
		return

	run_stats.set_gold(run_stats.gold - refresh_cost)
	_roll_slots(0)
	_sync_shop_ui()
	_update_shop_ui()


# 切换所有商店商品的冻结状态。
func frezee() -> void:
	if shop_slots.is_empty():
		return

	var should_freeze := false
	for slot_button in shop_slots:
		if not slot_button.is_frozen:
			should_freeze = true
			break

	for slot_button in shop_slots:
		if not slot_button.is_empty():
			slot_button.set_frozen(should_freeze)


# 处理购买逻辑：双击商品格购买，并将遗物塞进库存的第一个空位。
func buy_relic(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop.current_slot.size():
		return
	var player_inventory := _get_player_inventory()
	if run_stats == null or player_inventory == null:
		return

	var slot_ := shop.current_slot[slot_index]
	if slot_ == null or slot_.item == null:
		return

	var relic := slot_.item
	if run_stats.gold < relic.price:
		push_warning("Not enough gold to buy relic: %s" % relic.relic_name)
		return
	if not player_inventory.has_empty_slot():
		push_warning("Inventory is full, cannot buy relic: %s" % relic.relic_name)
		return

	run_stats.set_gold(run_stats.gold - relic.price)
	EventBus.buy_equipment.emit(relic)
	slot_.item = null

	var slot_button := shop_slots[slot_index]
	slot_button.set_frozen(false)
	slot_button.clear_relic()
	_update_shop_ui()


func _on_buy_equipment(relic: Relic) -> void:
	var player_inventory := _get_player_inventory()
	if run_stats == null or player_inventory == null:
		return

	var success := player_inventory.add_relic(relic)
	print(player_inventory)
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

		var slot_button: ShopEquipButton = null
		if slot_index < shop_slots.size():
			slot_button = shop_slots[slot_index]

		if slot_button != null and slot_button.is_frozen:
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


func _get_refresh_cost() -> int:
	if shop_config == null:
		return 0
	return max(shop_config.refresh_cost, 0)


func _get_player_inventory() -> Inventory:
	if run_stats == null or run_stats.player_build == null:
		return null

	return run_stats.player_build.player_inventory


func _is_left_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	return false
