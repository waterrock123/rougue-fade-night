## 四件装备的隔离回归测试。使用 --headless --script 运行，不启动游戏主场景。
## 依赖运行时 Autoload，因此不能加 --editor；遵循项目约定，不自动执行此测试。
extends SceneTree

var checks: int = 0
var failures: int = 0
var actor: Entity
var stats: StatsController
var abilities: AbilityController
var statuses: StatusController


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_setup_actor()
	if not is_instance_valid(actor) or not is_instance_valid(stats):
		printerr("测试环境初始化失败。")
		quit(1)
		return
	_test_flowers()
	_test_confidence()
	_test_joy_and_sale()
	actor.free()
	print("四件装备隔离测试：%d 项，失败 %d 项。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _setup_actor() -> void:
	actor = Entity.new()
	stats = StatsController.new()
	stats.name = "StatsController"
	stats.stats_data = StatsData.new()
	stats.stats_data.dexterity = 8
	actor.add_child(stats)
	abilities = AbilityController.new()
	abilities.name = "AbilityController"
	actor.add_child(abilities)
	statuses = StatusController.new()
	statuses.name = "StatusController"
	actor.add_child(statuses)
	root.add_child(actor)
	abilities.set_process(false)
	statuses.set_process(false)
	for _index: int in range(2):
		var ability: Ability = Ability.new()
		abilities.add_child(ability)
		abilities.abilities.append(ability)


func _context(relic: Relic, key: String = "test") -> RelicContext:
	return RelicContext.new(relic, actor, null, key, relic.effects, "base", "activate")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _reset_cooldowns() -> void:
	for ability: Ability in abilities.abilities:
		abilities.cooldowns[ability] = 10.0
		ability.current_cooldown = 10.0


func _test_flowers() -> void:
	var white: Relic = load("res://relics/level_5/130_白花.tres").duplicate(true) as Relic
	white.leveltip = Relic.LevelTip.LEVELUP
	var natural_dodge: float = stats.get_stat(&"dodge_rate")
	white.activate_relic(actor, null, "white")
	_check(is_equal_approx(stats.get_stat(&"dodge_rate"), natural_dodge + 0.1), "白花闪避加成")
	_reset_cooldowns()
	actor.damage_evaded.emit(DamageData.new())
	var total: float = float(abilities.cooldowns[abilities.abilities[0]]) + float(abilities.cooldowns[abilities.abilities[1]])
	_check(is_equal_approx(total, 15.0), "白花仅随机减半一个冷却")
	white.deactivate_relic(actor, null, "white")
	_check(is_equal_approx(stats.get_stat(&"dodge_rate"), natural_dodge), "白花卸下撤销属性")
	_reset_cooldowns()
	actor.damage_evaded.emit(DamageData.new())
	_check(abilities.abilities[0].current_cooldown == 10.0, "卸下后不再响应闪避")
	_test_red_flower(natural_dodge)


func _test_red_flower(natural_dodge: float) -> void:
	var red: Relic = load("res://relics/level_5/131_红花.tres").duplicate(true) as Relic
	red.leveltip = Relic.LevelTip.LEVELUP
	red.activate_relic(actor, null, "red")
	_check(is_equal_approx(stats.get_stat(&"dodge_rate"), natural_dodge - 0.2), "红花闪避惩罚")
	_reset_cooldowns()
	actor.damage_evaded.emit(DamageData.new())
	_check(abilities.abilities[0].current_cooldown == 5.0 and abilities.abilities[1].current_cooldown == 5.0, "全部剩余冷却减半且同步UI")
	var target: Entity = Entity.new()
	var hit: DamageData = DamageData.new()
	hit.target = target
	hit.final_damage = 1.0
	actor.damage_dealt.emit(hit)
	_check(not statuses.has_status(&"critical_dodge_bonus"), "非暴击不叠层")
	hit.is_crit = true
	actor.damage_dealt.emit(hit)
	actor.damage_dealt.emit(hit)
	_check(statuses.get_status(&"critical_dodge_bonus").stacks == 2, "暴击叠加两层状态")
	red.deactivate_relic(actor, null, "red")
	red.activate_relic(actor, null, "red")
	_check(statuses.get_status(&"critical_dodge_bonus").stacks == 2, "刷新装备不清除战斗成长")
	red.deactivate_relic(actor, null, "red")
	statuses.clear_all_statuses()
	_check(is_equal_approx(stats.get_stat(&"dodge_rate"), natural_dodge), "清理状态撤销战斗成长")
	target.free()


func _test_confidence() -> void:
	var relic: Relic = load("res://relics/special/210_胸有成竹的自信.tres").duplicate(true) as Relic
	relic.leveltip = Relic.LevelTip.LEVELUP
	var charm: float = stats.get_stat(&"charm")
	var speed: float = stats.get_stat(&"speed")
	relic.activate_relic(actor, null, "confidence")
	_check(stats.get_stat(&"dexterity") == 10.0, "包含装备自身敏捷")
	_check(stats.get_stat(&"charm") == charm + 2.0 and stats.get_stat(&"speed") == speed + 4.0, "10敏捷提供两组加成")
	stats.stats_data.dexterity = 13
	stats.recompute_stats()
	_check(stats.get_stat(&"charm") == charm + 3.0, "敏捷变化自动重算")
	relic.deactivate_relic(actor, null, "confidence")
	_check(stats.get_stat(&"charm") == charm and stats.get_stat(&"speed") == speed, "卸下撤销全部动态加成")
	var effect: PrimaryStatScalingEffect = PrimaryStatScalingEffect.new()
	_check(effect.calculate_bonus(4.9) == 0.0 and effect.calculate_bonus(-5.0) == 0.0, "分组向下取整且负值不倒扣")


func _test_joy_and_sale() -> void:
	var build: PlayerBuild = PlayerBuild.new()
	build.player_stats = stats.stats_data.duplicate(true) as StatsData
	build.player_inventory = Inventory.new()
	build.player_inventory.slots.append(Slot.new())
	stats.bind_player_build(build)
	var joy: Relic = load("res://relics/special/209_改变的欣喜.tres").duplicate(true) as Relic
	joy.leveltip = Relic.LevelTip.LEVELUP
	_check(joy.is_consumable, "欣喜已标记消耗品")
	var defense: float = build.player_stats.base_damage_reduction_rate
	var crit: float = build.player_stats.base_crit_chance
	joy.use_consumable(actor, null, "joy")
	_check(is_equal_approx(build.player_stats.base_damage_reduction_rate, defense + 0.02), "永久减伤写入构筑")
	_check(is_equal_approx(build.player_stats.base_crit_chance, crit + 0.02), "升级额外永久暴击")
	var white: Relic = load("res://relics/level_5/130_白花.tres").duplicate(true) as Relic
	white.gain_relic(actor, null, "white_gain")
	_check(build.player_inventory.slots[0].item == null, "获得白花不提前给予红花")
	white.sell_relic(actor, null, "white_sale")
	_check(build.player_inventory.slots[0].item != null and build.player_inventory.slots[0].item.id == "131", "出售白花获得红花")
