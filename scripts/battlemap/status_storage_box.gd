class_name StatusStorageBox
extends Area2D

## 每局共用 RunStats 中的一份状态仓；离开触碰区域后才能再次存取。
## 不在物理回调内直接施加状态，避免状态视觉生成触发 flushing queries。
var run_stats: RunStats
var touching_players: Dictionary = {}
var interaction_pending: bool = false
@onready var state_label: Label = $StateLabel
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D


func _ready() -> void:
	add_to_group("status_storage_box")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()


func bind_run_stats(stats: RunStats) -> void:
	run_stats = stats
	_refresh_visual()


func _on_body_entered(body: Node2D) -> void:
	if not (body is Entity) or not body.is_in_group("player"):
		return
	var id: int = body.get_instance_id()
	if touching_players.has(id):
		return
	touching_players[id] = true
	if not interaction_pending and EventBus.is_battle_active:
		interaction_pending = true
		_interact.call_deferred(body)


func _on_body_exited(body: Node2D) -> void:
	touching_players.erase(body.get_instance_id())


func _interact(collector: Entity) -> void:
	interaction_pending = false
	if not is_inside_tree() or not EventBus.is_battle_active or not is_instance_valid(collector) or collector.is_dead:
		return
	if run_stats == null:
		run_stats = MapTagBattleRules.find_run_stats(self)
	if run_stats == null or collector.get_status_controller() == null:
		return
	var controller: StatusController = collector.get_status_controller()
	if run_stats.stored_map_statuses.is_empty():
		_store(controller)
	else:
		_retrieve(controller)
	for box: Node in get_tree().get_nodes_in_group("status_storage_box"):
		box.call("_refresh_visual")


func _store(controller: StatusController) -> void:
	var ids: Array[StringName] = []
	for instance: StatusInstance in controller.statuses.values().duplicate():
		var snapshot: Dictionary = StatusStorageCodec.capture(instance)
		if snapshot.is_empty():
			continue
		run_stats.stored_map_statuses.append(snapshot)
		ids.append(instance.get_status_id())
	for id: StringName in ids:
		controller.remove_status(id)
	var count: int = run_stats.stored_map_statuses.size()
	FloatText.show_screen_tip("存入了%d种限时状态，剩余时间已暂停" % count if count > 0 else "没有可以储存的限时状态")


func _retrieve(controller: StatusController) -> void:
	var remaining_entries: Array[Dictionary] = []
	var count: int = 0
	for entry: Dictionary in run_stats.stored_map_statuses:
		var data: StatusData = StatusStorageCodec.decode_resource(entry.get("data", {})) as StatusData
		var instance: StatusInstance = controller.restore_stored_status(data, int(entry.get("stacks", 0)), float(entry.get("duration", 0.0)), entry.get("effect_states", []))
		if instance == null:
			remaining_entries.append(entry)
		else:
			count += 1
	run_stats.stored_map_statuses = remaining_entries
	FloatText.show_screen_tip("取回了%d种状态，按储存的剩余时间继续生效" % count)


func _refresh_visual() -> void:
	if state_label == null:
		return
	var count: int = run_stats.stored_map_statuses.size() if run_stats != null else 0
	state_label.text = "触碰存入限时状态" if count == 0 else "触碰取回：%d种状态" % count
	sprite.modulate = Color.WHITE if count == 0 else Color(0.7, 1.0, 1.0)
