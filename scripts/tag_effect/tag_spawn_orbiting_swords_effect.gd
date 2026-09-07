## 剑类套装效果：战斗中根据已计数的装备数量生成环绕飞剑。
## 只在真实 Entity 身上生成，Run 场景里的 PlayerBuildProxy 不会生成视觉/伤害实体。
class_name TagSpawnOrbitingSwordsEffect
extends TagEffect

@export var sword_manifest_scene: PackedScene = preload("res://scenes/ability/manifest/orbiting_sword_manifest.tscn")
@export var swords_per_counted_relic: int = 1
@export var max_swords: int = 8
@export var damage: float = 12.0
@export var lifetime: float = 0.0
@export var orbit_radius: float = 54.0
@export var orbit_speed: float = 2.1
@export var radius_wave_amplitude: float = 7.0
@export var slot_radius_variation: float = 4.0

var active_contexts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key: String = TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	_connect_signals()

	# 如果玩家在战斗中途装备变化导致效果激活，立即补生成飞剑。
	if EventBus.is_battle_active:
		_spawn_for_context(context)


func on_deactivate(context: TagEffectContext) -> void:
	_clear_for_context(context)
	active_contexts.erase(TagEffectRuntimeHelper.get_context_key(context))
	if active_contexts.is_empty():
		_disconnect_signals()


func _connect_signals() -> void:
	if not EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.connect(_on_battle_started)
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_finished):
		EventBus.battle_rewards_resolving.connect(_on_battle_finished)
	if not EventBus.battle_lost.is_connected(_on_battle_finished):
		EventBus.battle_lost.connect(_on_battle_finished)


func _disconnect_signals() -> void:
	if EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)
	if EventBus.battle_rewards_resolving.is_connected(_on_battle_finished):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_finished)
	if EventBus.battle_lost.is_connected(_on_battle_finished):
		EventBus.battle_lost.disconnect(_on_battle_finished)


func _on_battle_started() -> void:
	for value in active_contexts.values():
		var context: TagEffectContext = value as TagEffectContext
		_spawn_for_context(context)


func _on_battle_finished() -> void:
	for value in active_contexts.values():
		var context: TagEffectContext = value as TagEffectContext
		_clear_for_context(context)


func _spawn_for_context(context: TagEffectContext) -> void:
	if context == null:
		return

	var owner_entity: Entity = TagEffectRuntimeHelper.get_owner_entity(context)
	if owner_entity == null:
		return

	var sword_count: int = _get_sword_count(context)
	if sword_count <= 0:
		return

	var source_key: StringName = _get_source_key(context)
	OrbitingSwordHelper.clear_swords_for_source(owner_entity, source_key)
	OrbitingSwordHelper.spawn_swords(
		owner_entity,
		sword_count,
		source_key,
		sword_manifest_scene,
		damage,
		lifetime,
		orbit_radius,
		orbit_speed,
		radius_wave_amplitude,
		slot_radius_variation
	)


func _clear_for_context(context: TagEffectContext) -> void:
	if context == null:
		return

	var owner_entity: Entity = TagEffectRuntimeHelper.get_owner_entity(context)
	if owner_entity == null:
		return

	OrbitingSwordHelper.clear_swords_for_source(owner_entity, _get_source_key(context))


func _get_sword_count(context: TagEffectContext) -> int:
	var counted_count: int = max(context.counted_relics.size(), context.tag_count)
	var raw_count: int = counted_count * max(swords_per_counted_relic, 0)
	return clamp(raw_count, 0, max(max_swords, 0))


func _get_source_key(context: TagEffectContext) -> StringName:
	return StringName("%s_orbiting_swords" % context.effect_key)
