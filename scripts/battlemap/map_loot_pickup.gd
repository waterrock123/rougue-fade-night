## 通用预抽宝罐：生成时决定装备，触碰后只发放已决定的奖励。
## 复用金色闪光的商人权重与等级筛选；本战斗随机不推进商店/事件种子流。
class_name MapLootPickup
extends GoldenFlashPickup

var reward: MapLootReward
var jackpot: bool = false
var collector_owner: Entity
var battle_scene: PlayScene
var contents_ready: bool = false


func _ready() -> void:
	prepare_reward_on_ready = false
	super._ready()
	var label: Label = get_node_or_null("Label") as Label
	if label != null:
		label.text = "大奖宝罐" if jackpot else "宝罐"
		label.modulate = Color.GOLD if jackpot else Color.WHITE
	pickup_display_name = "大奖宝罐" if jackpot else "宝罐"


func prepare_contents() -> void:
	if contents_ready or reward == null:
		return
	if reward.random_relic:
		prepare_reward()
		if prepared_reward_relic != null and reward.upgraded_relic:
			prepared_reward_relic.leveltip = Relic.LevelTip.LEVELUP
	contents_ready = true


func _get_candidate_relics(_stats: RunStats) -> Array[Relic]:
	return cached_candidate_relics


func _roll_seeded_float_range(from: float, to: float) -> float:
	return randf_range(from, to)


func _can_collect(collector: Entity) -> bool:
	return contents_ready and EventBus.is_battle_active and collector == collector_owner \
		and is_instance_valid(battle_scene) and not battle_scene.battle_completion_started


func _apply_pickup(collector: Entity) -> void:
	# 获得装备可能合成或生成其他物件，物理查询结束后再发放。
	_grant.call_deferred(collector)


func _grant(collector: Entity) -> void:
	if not is_instance_valid(collector) or collector.is_dead or run_stats == null:
		queue_free()
		return
	if not EventBus.is_battle_active or not is_instance_valid(battle_scene) or battle_scene.battle_completion_started:
		queue_free()
		return
	var details: Array[String] = []
	# 先接收装备，再发放组合奖励；满背包时保留宝罐，避免金币被重复领取。
	if reward.random_relic and prepared_reward_relic != null:
		if run_stats.player_build == null or not run_stats.player_build.add_relic(prepared_reward_relic):
			show_collected_tip("背包已满，宝罐保留，可腾出空间后领取")
			collected_once = false
			delay_collection_for(1.5)
			return
		details.append("获得%s%s" % ["升级态" if reward.upgraded_relic else "", prepared_reward_relic.relic_name])
		prepared_reward_relic.gain_relic(collector, null, "map_loot_%s" % get_instance_id())
	elif reward.random_relic:
		details.append("装备池为空，未能抽取装备")
	if reward.gold > 0:
		run_stats.set_gold(run_stats.gold + reward.gold)
		details.append("金币+%d" % reward.gold)
	if reward.heal > 0.0:
		details.append("恢复生命%s" % collector.apply_heal(reward.heal))
	if reward.energy > 0.0:
		details.append("恢复能量%s" % _restore_energy(collector, reward.energy))
	show_collected_tip("、".join(details))
	queue_free()


func _restore_energy(collector: Entity, amount: float) -> float:
	if not is_instance_valid(collector.stats_controller):
		return 0.0
	var maximum: float = collector.stats_controller.get_stat(&"max_energy", collector.max_energy)
	var previous: float = collector.current_energy
	collector.current_energy = minf(previous + amount, maximum)
	collector.stats_controller.current_energy = collector.current_energy
	collector.stats_controller.sync_runtime_resources()
	EventBus.player_energy_changed.emit(collector.current_energy, maximum)
	return collector.current_energy - previous
