class_name PistolDuelRoom
extends EventRoom

const BOUNTY_SCENE: PackedScene = preload("res://entity/enemy/strong_robot.tscn")
const RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")

@onready var desc_label: Label = $DescLabel
@onready var duel_button: EventRoomButton = $DuelButton
@onready var challenge_button: EventRoomButton = $ChallengeButton
@onready var gun_button: EventRoomButton = $GunButton


func setup() -> void:
	duel_button.setup_button(_duel)
	challenge_button.setup_button(_challenge)
	gun_button.setup_button(_use_own_gun)
	gun_button.visible = run_stats != null and run_stats.picked_character != null and run_stats.picked_character.get_character_match_ids().has(&"scount")


## 敏捷和幸运共同提高胜率；事件随机使用本局种子流。
func _duel() -> void:
	var controller: StatsController = _get_stats_controller()
	if controller == null:
		return
	var chance: float = clamp(0.25 + controller.get_stat(&"dexterity") * 0.02 + controller.get_stat(&"luck") * 0.02, 0.05, 0.95)
	var won: bool = RunRng.randf() < chance
	if won:
		run_stats.set_gold(run_stats.gold + 6)
	else:
		var maximum: float = controller.get_stat(&"max_health")
		var remaining: float = max(maximum * 0.01, 0.01)
		run_stats.player_build.current_health = remaining
		controller.current_health = remaining
		controller.sync_runtime_resources()
		EventBus.player_health_changed.emit(remaining, maximum)
	_finish(duel_button.get_pressed_desc(0 if won else 1))


func _challenge() -> void:
	run_stats.queue_bounty_enemy_for_next_battle(BOUNTY_SCENE, 1, 8, false)
	_finish(challenge_button.get_pressed_desc())


func _use_own_gun() -> void:
	var candidates: Array[Relic] = []
	for relic: Relic in RELIC_POOL.get_relics_by_level(3):
		for tag: RelicTag in relic.tags:
			if tag != null and tag.tag_name == "弹药":
				candidates.append(relic)
				break
	if candidates.is_empty() or _free_inventory_slots() < 2:
		desc_label.text = "没有足够的三阶弹药奖励，或背包已经放不下两件装备。"
		return
	for index: int in range(2):
		var reward: Relic = (RunRng.pick(candidates) as Relic).duplicate(true) as Relic
		run_stats.player_build.add_relic(reward)
	run_stats.set_gold(run_stats.gold + 3)
	_finish(gun_button.get_pressed_desc())


func _free_inventory_slots() -> int:
	var count: int = 0
	for slot: Slot in run_stats.player_build.player_inventory.slots:
		if slot == null or slot.item == null:
			count += 1
	return count


func _get_stats_controller() -> StatsController:
	var run: Run = _get_run()
	if run == null or run.player_build_proxy == null:
		return null
	return run.player_build_proxy.get_stats_controller()


func _finish(result_text: String) -> void:
	desc_label.text = result_text
	for button: EventRoomButton in [duel_button, challenge_button, gun_button]:
		button.queue_free()
	var run: Run = _get_run()
	if run != null and run.player_build_proxy != null:
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
