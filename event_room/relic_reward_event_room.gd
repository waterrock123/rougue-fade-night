## 提供事件房间共用的特殊装备发放、属性读取与结算流程。
class_name RelicRewardEventRoom
extends EventRoom

@onready var desc_label: Label = $DescLabel


func _get_run() -> Run:
	var node: Node = get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _get_current_stat(stat_name: StringName) -> float:
	var run: Run = _get_run()
	if run == null or run.player_build_proxy == null:
		return 0.0
	var controller: StatsController = run.player_build_proxy.get_stats_controller()
	return controller.get_stat(stat_name) if controller != null else 0.0


func _grant_special_relic(relic_template: Relic) -> bool:
	if relic_template == null or run_stats == null or run_stats.player_build == null:
		return false
	var reward: Relic = relic_template.duplicate(true) as Relic
	if not run_stats.player_build.can_accept_relic(reward):
		desc_label.text = "背包暂时装不下这件装备。请先整理背包，再做选择。"
		return false
	if not run_stats.player_build.add_relic(reward):
		desc_label.text = "装备发放失败，请整理背包后重试。"
		return false
	return true


func _finish_choice(button: EventRoomButton, result_index: int, buttons: Array) -> void:
	desc_label.text = button.get_pressed_desc(result_index)
	for option: EventRoomButton in buttons:
		if option != null:
			option.queue_free()
	var run: Run = _get_run()
	if run != null and run.player_build_proxy != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


## 使用本局种子和地图坐标生成事件私有随机流，读档重进同一房间仍得到相同结果。
func _make_room_rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var room: Room = _get_run().current_room if _get_run() != null else null
	var row: int = room.row if room != null else 0
	var column: int = room.column if room != null else 0
	# 同一房间读档结果不变，不同楼层的同坐标使用独立事件随机流。
	var floor_index: int = run_stats.current_floor_index if run_stats != null else 0
	rng.seed = RunRng.seed_value + row * 1009 + column * 9176 + floor_index * 104729 + salt
	return rng


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
