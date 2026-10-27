## 装备施法召唤的运行时监听器。每件装备独立计数，不监听召唤物的技能。
class_name AbilityCastSummonRunner
extends Node

var settings: AbilityCastSummonPetEffect
var relic_context: RelicContext
var actor: Entity
var controller: AbilityController
var pets: Array[SummonPet] = []
var equipped: bool = false
var pending_spawns: int = 0


func configure(effect: AbilityCastSummonPetEffect, context: RelicContext) -> void:
	settings = effect
	relic_context = context
	actor = context.owner as Entity
	equipped = true
	controller = actor.get_node_or_null("AbilityController") as AbilityController
	if controller != null and not controller.ability_triggered.is_connected(_on_ability_cast):
		controller.ability_triggered.connect(_on_ability_cast)


func request_cleanup() -> void:
	equipped = false
	# refresh_all 会先停用再同步启用。延后一帧清理，保留仍穿戴装备的召唤物。
	call_deferred("_finish_cleanup")


func _finish_cleanup() -> void:
	if not equipped:
		_clear_pets()
		queue_free()


func _process(_delta: float) -> void:
	if not EventBus.is_battle_active or not is_instance_valid(actor) or actor.is_dead:
		_clear_pets()


func _on_ability_cast(ability: Ability, caster: Entity) -> void:
	if not _can_summon() or caster != actor or not is_instance_valid(ability):
		return
	if settings.exclude_basic_attack and _is_basic_attack(ability):
		return
	_prune_pets()
	if pets.size() + pending_spawns >= settings.max_alive_pets or randf() >= settings.summon_chance:
		return
	pending_spawns += 1
	# 施法可能在碰撞回调里发生，必须延迟创建碰撞体。
	call_deferred("_spawn_pet")


func _is_basic_attack(ability: Ability) -> bool:
	if ability.skill_data != null:
		return ability.skill_data.is_basic_attack or ability.skill_data.id == &"101"
	return controller != null and not controller.abilities.is_empty() and controller.abilities[0] == ability


func _can_summon() -> bool:
	return equipped and EventBus.is_battle_active and is_instance_valid(actor) \
		and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
		and not actor.is_dead and settings.pet_scene != null


func _spawn_pet() -> void:
	pending_spawns = maxi(pending_spawns - 1, 0)
	if not _can_summon():
		return
	_prune_pets()
	if pets.size() >= settings.max_alive_pets:
		return
	var spawn_position: Variant = _safe_position()
	if not spawn_position is Vector2:
		return
	var pet: SummonPet = settings.pet_scene.instantiate() as SummonPet
	if pet == null:
		push_warning("施法召唤场景的根节点必须继承 SummonPet。")
		return
	_prepare_pet(pet)
	var parent: Node = actor.get_parent()
	pet.position = parent.to_local(spawn_position) if parent is Node2D else spawn_position
	pet.summoner = actor
	var upgraded: bool = relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP
	pet.died.connect(_on_pet_died.bind(upgraded))
	pets.append(pet)
	parent.add_child(pet)
	pet.set_summoner(actor)
	pet.play_spawn_animation()


func _prepare_pet(pet: SummonPet) -> void:
	var stats: StatsController = pet.get_node_or_null("StatsController") as StatsController
	if stats != null and stats.stats_data != null:
		stats.stats_data = stats.stats_data.duplicate(true) as StatsData
	var timer: SummonLifetime = pet.get_node_or_null("SummonLifetime") as SummonLifetime
	if timer == null:
		timer = SummonLifetime.new()
		timer.name = "SummonLifetime"
		pet.add_child(timer)
	timer.lifetime = settings.lifetime
	var bonus: float = 0.0
	if actor.stats_controller != null:
		bonus = maxf(actor.stats_controller.get_stat(settings.bonus_damage_stat) * settings.bonus_damage_ratio, 0.0)
	for component: Node in pet.find_children("*", "", true, false):
		if component is AbilityDealDamage:
			(component as AbilityDealDamage).damage += bonus


func _safe_position() -> Variant:
	var desired: Vector2 = actor.global_position + Vector2.RIGHT.rotated(randf() * TAU) * settings.spawn_radius
	var map: BattleMap = get_tree().get_first_node_in_group("battle_map") as BattleMap
	if map == null:
		return desired
	var reserved: Array[Vector2] = []
	for pet: SummonPet in pets:
		reserved.append(pet.global_position)
	return map.get_nearest_playable_position(desired, 6, 0, reserved, 16.0)


func _on_pet_died(_pet: Entity, upgraded: bool) -> void:
	if not upgraded or not _can_summon() or _pet.is_queued_for_deletion():
		return
	# 不持有可能正在退树的 RelicController；沿主人 StatsController 获取本局构筑。
	var context := RelicContext.new(relic_context.own_relic, actor, null,
		relic_context.relic_key, settings.upgraded_death_effects, "death", "use")
	for effect: RelicEffect in settings.upgraded_death_effects:
		if effect != null:
			effect.on_use(context, relic_context.relic_key + "_pet_death")


func _prune_pets() -> void:
	for index: int in range(pets.size() - 1, -1, -1):
		if not is_instance_valid(pets[index]) or pets[index].is_dead or pets[index].is_queued_for_deletion():
			pets.remove_at(index)


func _clear_pets() -> void:
	for pet: SummonPet in pets:
		if is_instance_valid(pet):
			pet.queue_free()
	pets.clear()


func _exit_tree() -> void:
	if is_instance_valid(controller) and controller.ability_triggered.is_connected(_on_ability_cast):
		controller.ability_triggered.disconnect(_on_ability_cast)
	_clear_pets()
