class_name MapTagBattleController
extends Node

## 本场地图规则在进场时固定；不逐帧遍历装备或标签数据库。
var run_stats: RunStats
var player: Entity
var values: Dictionary = {}


func _ready() -> void:
	add_to_group("map_tag_battle_rules")
	values = MapTagBattleRules.build_values(run_stats)
	if is_instance_valid(player):
		player.terrain_road_speed_bonus = value("road_speed_bonus")
	EventBus.map_object_destroyed.connect(_on_object_destroyed)
	EventBus.map_pickup_collected.connect(_on_pickup_collected)
	EventBus.battle_started.connect(_on_battle_started)


func _exit_tree() -> void:
	if EventBus.map_object_destroyed.is_connected(_on_object_destroyed):
		EventBus.map_object_destroyed.disconnect(_on_object_destroyed)
	if EventBus.map_pickup_collected.is_connected(_on_pickup_collected):
		EventBus.map_pickup_collected.disconnect(_on_pickup_collected)
	if EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)
	if is_instance_valid(player):
		player.terrain_road_speed_bonus = 0.0


func value(effect_id: String) -> float:
	return float(values.get(effect_id, 0.0))


## 地图中登记的悬赏怪共用入口，包括自然生成和装备/事件生成；同一只不能重复加赏金。
func apply_bounty_bonus(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.has_meta("map_tag_bounty_bonus_applied"):
		return
	enemy.bounty_gold += maxi(int(value("bounty_gold_bonus")), 0)
	enemy.set_meta("map_tag_bounty_bonus_applied", true)


func _on_battle_started() -> void:
	# 延迟至正式进场后，额外怪物仍走原来的安全落点和悬赏池，不参与胜利计数。
	if randf() >= clampf(value("extra_bounty_chance"), 0.0, 1.0):
		return
	var spawner: EnemySpawner = get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	if spawner != null:
		spawner.spawn_random_bounty_enemy(Vector2.ZERO, false, true)


func _on_object_destroyed(_map_object: Node, killer: Entity) -> void:
	if not EventBus.is_battle_active or not is_instance_valid(player) or killer != player or player.is_dead:
		return
	if randf() >= clampf(value("destroy_armor_chance"), 0.0, 1.0):
		return
	# 每次生成独立 id，每一层各自计时，不会把旧护甲刷新成永久层数。
	var data: StatusData = _make_stat_status(run_stats.allocate_map_status_id(&"map_guard"), "守御", &"static_damage_reduction", 1.0, 10.0)
	player.get_status_controller().add_status(data, player, data.id)


func _on_pickup_collected(pickup: Node, collector: Entity) -> void:
	if not EventBus.is_battle_active or collector != player or not (pickup is TemporaryEnergyPickup):
		return
	var amount: float = value("star_max_energy")
	if amount <= 0.0 or not is_instance_valid(player) or player.is_dead:
		return
	var data: StatusData = _make_stat_status(&"map_wisdom_energy", "智慧：能量上限", &"max_energy", amount, -1.0)
	data.max_stacks = 999999
	data.stack_mode = StatusData.StackMode.ADD_STACK
	player.get_status_controller().add_status(data, player, &"map_wisdom")
	FloatText.show_screen_tip("智慧：能量上限 +%s，持续至战斗结束" % str(amount))


func _make_stat_status(id: StringName, title: String, stat: StringName, amount: float, duration: float) -> StatusData:
	var effect: StatusAddStatEffect = StatusAddStatEffect.new()
	effect.stat_name = stat
	effect.value_per_stack = amount
	var data: StatusData = StatusData.new()
	data.id = id
	data.status_name = title
	data.desc = "%s +%s%s" % ["护甲" if stat == &"static_damage_reduction" else "能量上限", str(amount), "，持续10秒" if duration > 0.0 else "，持续至战斗结束"]
	data.duration = duration
	data.polarity = StatusData.Polarity.POSITIVE
	data.effects.append(effect)
	return data
