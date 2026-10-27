## 周期环绕实体运行器：暂停时不计时，装备刷新保留进度，卸下/死亡/结算时清理。
class_name PeriodicOrbitingManifestRunner
extends Node

var settings: PeriodicOrbitingManifestEffect
var actor: Entity
var remaining: float = -1.0
var equipped: bool = false
var finished: bool = false
var manifests: Array[OrbitingSwordManifest] = []


func _ready() -> void:
	EventBus.battle_rewards_resolving.connect(_on_battle_finished)
	EventBus.battle_lost.connect(_on_battle_finished)


func configure(effect: PeriodicOrbitingManifestEffect, owner_entity: Entity) -> void:
	settings = effect
	actor = owner_entity
	equipped = true
	if remaining < 0.0:
		remaining = maxf(settings.interval, 0.1)


func request_cleanup() -> void:
	equipped = false
	_finish_cleanup.call_deferred()


func _finish_cleanup() -> void:
	if not equipped:
		_clear_manifests()
		queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead:
		_clear_manifests()
		return
	if not _can_spawn():
		return
	remaining -= delta
	if remaining <= 0.0:
		remaining = maxf(settings.interval, 0.1)
		_spawn.call_deferred()


func _can_spawn() -> bool:
	return equipped and not finished and EventBus.is_battle_active and settings != null and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_dead


func _spawn() -> void:
	if not _can_spawn() or settings.manifest_scene == null:
		return
	var node: Node = settings.manifest_scene.instantiate()
	if not node is OrbitingSwordManifest:
		node.free()
		push_warning("周期环绕场景必须继承OrbitingSwordManifest。")
		return
	var manifest: OrbitingSwordManifest = node as OrbitingSwordManifest
	manifest.damage = settings.damage
	manifest.lifetime = settings.manifest_lifetime
	# 先判断有效性再访问实例，不把已释放对象传给带类型的回调。
	for index: int in range(manifests.size() - 1, -1, -1):
		if not is_instance_valid(manifests[index]):
			manifests.remove_at(index)
	manifests.append(manifest)
	actor.get_parent().add_child(manifest)
	manifest.setup_orbit(actor, StringName(name), 0, 1)


func _on_battle_finished() -> void:
	finished = true
	_clear_manifests()


func _clear_manifests() -> void:
	for manifest: OrbitingSwordManifest in manifests:
		if is_instance_valid(manifest):
			manifest.queue_free()
	manifests.clear()
