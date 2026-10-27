## 单个装备来源的 Boss 战盟友属性光环：进场快照、后续盟友补发、离场清理。
class_name BossAllyStatsAura
extends Node

var caster: Entity
var source_key: String
var primary_ratio: float = 0.3
var flat_bonus: float = 0.0
var bonuses: Dictionary = {}
var affected: Array[WeakRef] = []
var active: bool = false


func _ready() -> void:
	EventBus.battle_started.connect(_start)
	get_tree().node_added.connect(_on_node_added)
	if EventBus.is_battle_active:
		_start()


func _start() -> void:
	if not is_instance_valid(caster) or caster.stats_controller == null:
		return
	var scene: Node = caster.get_parent()
	while scene != null and not (scene is PlayScene):
		scene = scene.get_parent()
	if scene == null:
		return
	var battle: PlayScene = scene as PlayScene
	if battle.pending_battle_stats == null or battle.pending_battle_stats.battle_tier != 3:
		return
	# 装备刷新会重新创建光环，快照保存在本场玩家节点上，不能重新读取变动后的属性。
	var snapshot_key: StringName = StringName("boss_aura_snapshot_" + source_key)
	if caster.has_meta(snapshot_key):
		bonuses = caster.get_meta(snapshot_key)
	else:
		for stat: StringName in StatsController.PRIMARY_STATS:
			bonuses[stat] = floorf(caster.stats_controller.get_stat(stat) * primary_ratio) + flat_bonus
		caster.set_meta(snapshot_key, bonuses.duplicate())
	active = true
	for group: String in ["player_ally", "player"]:
		for ally: Node in get_tree().get_nodes_in_group(group):
			_apply_to(ally)


func _on_node_added(node: Node) -> void:
	if active and node is Entity:
		# 等召唤脚本完成 ready、分组和专属 Stats 替换后再加成。
		_apply_reference.call_deferred(weakref(node))


func _apply_reference(reference: WeakRef) -> void:
	var value: Variant = reference.get_ref()
	if is_instance_valid(value):
		_apply_to(value as Node)


func _apply_to(node: Node) -> void:
	if not active or not is_instance_valid(node) or not node.is_inside_tree() or node == caster:
		return
	if not node.is_in_group("player_ally") and not node.is_in_group("player"):
		return
	var ally: Entity = node as Entity
	if ally == null or ally.is_dead or ally.stats_controller == null:
		return
	var modifiers: Array[Modifier] = []
	for stat: StringName in bonuses:
		modifiers.append(Modifier.create_flat(stat, bonuses[stat], source_key))
	ally.stats_controller.set_effect_modifiers(source_key, modifiers)
	for reference: WeakRef in affected:
		if reference.get_ref() == ally:
			return
	affected.append(weakref(ally))


func stop() -> void:
	active = false
	if EventBus.battle_started.is_connected(_start):
		EventBus.battle_started.disconnect(_start)
	if is_inside_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for reference: WeakRef in affected:
		var ally: Entity = reference.get_ref() as Entity
		if is_instance_valid(ally) and is_instance_valid(ally.stats_controller):
			ally.stats_controller.clear_effect_modifiers(source_key)
	affected.clear()


func _exit_tree() -> void:
	stop()
