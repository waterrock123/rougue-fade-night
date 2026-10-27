## 每个装备来源一个管理器：绑定已有及新召唤物，卸装只移除此来源的组件。
class_name SummonCombatAuraRunner
extends Node

var settings: SummonCombatAuraEffect
var actor: Entity
var source_key: String
var equipped: bool = false
var attached: Array[WeakRef] = []
var battle: PlayScene


func configure(effect: SummonCombatAuraEffect, caster: Entity, key: String) -> void:
	settings = effect
	actor = caster
	source_key = key
	equipped = true
	var ancestor: Node = actor.get_parent()
	while ancestor != null and not ancestor is PlayScene:
		ancestor = ancestor.get_parent()
	battle = ancestor as PlayScene
	if not EventBus.battle_started.is_connected(_bind_existing):
		EventBus.battle_started.connect(_bind_existing)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	_bind_existing()


func can_work() -> bool:
	return equipped and EventBus.is_battle_active and is_instance_valid(actor) \
		and actor.is_inside_tree() and not actor.is_dead and not actor.is_queued_for_deletion() \
		and is_instance_valid(battle) and not battle.battle_completion_started


func request_cleanup() -> void:
	equipped = false
	# 装备刷新会同步再次启用；真正卸装才移除光环，避免重置每秒计时。
	call_deferred("_finish_cleanup")


func _finish_cleanup() -> void:
	if not equipped:
		queue_free()


func _bind_existing() -> void:
	if not can_work():
		return
	for node: Node in get_tree().get_nodes_in_group("summon_pet"):
		_attach(node)


func _on_node_added(node: Node) -> void:
	if equipped and node is SummonPet:
		# 等召唤物 ready 分组并设置 summoner，避免读取半初始化节点。
		_attach_deferred.call_deferred(weakref(node))


func _attach_deferred(reference: WeakRef) -> void:
	var node: Variant = reference.get_ref()
	if is_instance_valid(node):
		_attach(node as Node)


func _attach(node: Node) -> void:
	if not can_work() or not node is SummonPet or node.is_queued_for_deletion():
		return
	var pet: SummonPet = node as SummonPet
	if pet.is_dead or pet.get_summoner() != actor:
		return
	var component_name: String = "CombatAura_%s" % get_instance_id()
	if pet.get_node_or_null(component_name) != null:
		return
	var component := SummonCombatAura.new()
	component.name = component_name
	component.manager = self
	pet.add_child(component)
	for index: int in range(attached.size() - 1, -1, -1):
		if not is_instance_valid(attached[index].get_ref()):
			attached.remove_at(index)
	attached.append(weakref(component))


func request_explosion(position: Vector2) -> void:
	if can_work() and settings.explode_on_death:
		# 死亡可能发生在碰撞信号中，延迟伤害和视觉生成，并只保存死亡坐标。
		_explode.call_deferred(position)


func _explode(position: Vector2) -> void:
	if not can_work():
		return
	var scaling := DamageScalingRule.new()
	scaling.enabled = false
	for enemy: Entity in SummonCombatAura.find_enemies(actor, position, settings.explosion_radius):
		if not can_work():
			break
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_queued_for_deletion():
			continue
		var damage := DamageData.create(settings.explosion_damage, settings.explosion_damage_types,
			["relic", "summon_death", "explosion"], actor, enemy, false, scaling, &"", -1, 0.0)
		enemy.apply_damage(damage)
	_spawn_explosion_visual(position)


func _spawn_explosion_visual(position: Vector2) -> void:
	if settings.explosion_visual == null or not can_work():
		return
	var visual: AbilityManifest = settings.explosion_visual.instantiate() as AbilityManifest
	if visual == null:
		return
	actor.get_parent().add_child(visual)
	visual.global_position = position
	visual.activate(AbilityContext.new(actor, null))


func _exit_tree() -> void:
	equipped = false
	if EventBus.battle_started.is_connected(_bind_existing):
		EventBus.battle_started.disconnect(_bind_existing)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for reference: WeakRef in attached:
		var component: Variant = reference.get_ref()
		if is_instance_valid(component):
			component.queue_free()
	attached.clear()
