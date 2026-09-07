## 持续扇形投射物组件。
## 按固定间隔生成真实 ProjectileManifest，而不是用 GPUParticles2D 伪造命中。
## 因此每一发子弹都能独立碰撞、造成伤害、触发暴击和投射物相关效果。
class_name AbilitySustainedProjectileFan
extends AbilityComponent

enum FirePattern {
	BURST,
	SEQUENTIAL,
}

@export_group("Projectile")
## 每一发实际生成的投射物场景。
@export var manifest_scene: PackedScene
## 投射物从施法者前方生成的距离，避免刚生成就和施法者的碰撞区域重叠。
@export var forward_offset: float = 18.0
## 传给投射物的目标距离，用于确定其初始飞行方向。
@export var projectile_target_distance: float = 600.0
## 是否让投射物视觉朝向各自的散射方向。
@export var rotate_to_direction: bool = true
## 每发投射物的最低飞行速度倍率；1.0 表示场景中配置的原始速度。
@export_range(0.1, 3.0, 0.01) var min_projectile_speed_multiplier: float = 1.0
## 每发投射物的最高飞行速度倍率。与最低倍率相同即关闭速度随机。
@export_range(0.1, 3.0, 0.01) var max_projectile_speed_multiplier: float = 1.0

@export_group("Barrage")
## 整段弹幕持续时间。
@export_range(0.1, 10.0, 0.05) var barrage_duration: float = 1.5
## 批射会一次生成一小批子弹；逐发模式会每次只生成一颗子弹。
@export var fire_pattern: FirePattern = FirePattern.BURST
## 两批子弹之间的间隔；越小，弹幕越连续。
@export_range(0.02, 1.0, 0.01) var burst_interval: float = 0.1
## 每一批的基础子弹数。总子弹数会按持续时间和该数值计算。
@export_range(1, 32, 1) var base_projectiles_per_burst: int = 4
## 子弹相对锁定方向的完整散射角度。
@export_range(0.0, 180.0, 1.0) var fan_angle_degrees: float = 52.0
## 在均匀扇形的基础上加入轻微抖动，让弹幕视觉更自然。
@export_range(0.0, 30.0, 0.1) var random_angle_jitter_degrees: float = 3.0

@export_group("Rhythm Variation")
## 批次间隔的随机幅度。随机后的所有间隔仍会重分配为原总时长，不改变整段弹幕的节奏长度。
@export_range(0.0, 0.9, 0.01) var interval_randomness: float = 0.45
## 单次批次转移的最大子弹数；只改变每批数量，不会改变整次施放的总子弹数。
@export_range(0, 16, 1) var projectile_count_variation: int = 2
## 一次施放中执行多少轮批次数量转移。数值越高，连续几批之间的疏密变化越明显。
@export_range(0.0, 4.0, 0.1) var projectile_count_variation_strength: float = 1.5

@export_group("Ammo Bonus")
## 统计背包内拥有此标签的遗物数量。
@export var ammo_tag: RelicTag
## 当标签资源不存在时，可用标签名称作为备用匹配方式。
@export var ammo_tag_name: StringName = &"弹药"
## 每件弹药装备提供的总子弹量加成，例如 0.2 就是 +20%。
@export_range(0.0, 1.0, 0.01) var bonus_per_ammo_relic: float = 0.2
## 弹药带来的额外子弹量上限；1.0 表示最多额外 +100%。
@export_range(0.0, 5.0, 0.01) var max_ammo_bonus: float = 1.0
## 锁住的临时背包格默认不计入，避免未整理的缓冲装备意外提供战斗收益。
@export var include_locked_inventory_slots: bool = false

@export_group("Caster Lock")
## 弹幕期间锁住施法者的自主移动，但不会阻止外部击退等强制位移。
@export var lock_caster_movement: bool = true
## 在最后一批子弹后额外保留的短暂移动锁，避免最后一批尚未生成完就能移动。
@export_range(0.0, 1.0, 0.01) var movement_lock_extra: float = 0.05

var is_firing: bool = false


func _activate(context: AbilityContext) -> void:
	if is_firing or manifest_scene == null or context == null or context.caster == null:
		return
	if not context.is_caster_action_valid():
		return

	is_firing = true
	_run_barrage(context)


## 将总子弹数平均分配到每一批，确保“每件弹药 +20%”不会被单批取整放大或吞掉。
func _run_barrage(context: AbilityContext) -> void:
	var caster: Entity = context.caster
	var safe_interval: float = maxf(burst_interval, 0.02)
	var burst_count: int = maxi(int(ceil(maxf(barrage_duration, safe_interval) / safe_interval)), 1)
	var projectile_total: int = _get_total_projectile_count(caster, burst_count)

	if lock_caster_movement and caster.has_method("lock_movement"):
		caster.lock_movement(maxf(barrage_duration, safe_interval) + movement_lock_extra)

	if fire_pattern == FirePattern.SEQUENTIAL:
		await _run_sequential_barrage(context, projectile_total, burst_count, safe_interval)
	else:
		await _run_burst_barrage(context, projectile_total, burst_count, safe_interval)

	is_firing = false


## 传统批射模式：适合霰弹、弹幕墙等需要一瞬间推出多个投射物的技能。
func _run_burst_barrage(
	context: AbilityContext,
	projectile_total: int,
	burst_count: int,
	safe_interval: float
) -> void:
	# 先确定整段弹幕的随机节奏表，使中途的 await 不会影响总数量和总时长。
	var projectile_counts: Array[int] = _build_projectile_counts(projectile_total, burst_count)
	var burst_intervals: Array[float] = _build_burst_intervals(burst_count, safe_interval)
	for burst_index: int in range(burst_count):
		if not context.is_caster_action_valid():
			break

		var projectile_count: int = projectile_counts[burst_index]
		_spawn_burst(context, projectile_count)

		if burst_index < burst_count - 1:
			await get_tree().create_timer(burst_intervals[burst_index], false).timeout



## 逐发模式：每颗子弹都独立决定角度、速度与极短的下一发间隔，适合凌乱扫射效果。
func _run_sequential_barrage(
	context: AbilityContext,
	projectile_total: int,
	burst_count: int,
	safe_interval: float
) -> void:
	var total_wait_duration: float = safe_interval * float(maxi(burst_count - 1, 0))
	var shot_intervals: Array[float] = _build_randomized_intervals(projectile_total, total_wait_duration)
	var base_direction: Vector2 = _get_base_direction(context)

	for projectile_index: int in range(projectile_total):
		if not context.is_caster_action_valid():
			break

		var direction: Vector2 = _get_random_fan_direction(base_direction)
		var speed_multiplier: float = _get_random_speed_multiplier()
		_spawn_one_projectile(context, direction, speed_multiplier)

		if projectile_index < projectile_total - 1:
			await get_tree().create_timer(shot_intervals[projectile_index], false).timeout


func _get_total_projectile_count(caster: Entity, burst_count: int) -> int:
	var safe_base_per_burst: int = maxi(base_projectiles_per_burst, 1)
	var base_total: int = safe_base_per_burst * maxi(burst_count, 1)
	var ammo_count: int = _count_ammo_relics(caster)
	var extra_bonus: float = minf(float(ammo_count) * bonus_per_ammo_relic, maxf(max_ammo_bonus, 0.0))
	return maxi(int(round(float(base_total) * (1.0 + extra_bonus))), 1)


func _get_projectiles_in_burst(projectile_total: int, burst_count: int, burst_index: int) -> int:
	var safe_burst_count: int = maxi(burst_count, 1)
	var even_count: int = projectile_total / safe_burst_count
	var remaining_count: int = projectile_total % safe_burst_count
	return even_count + (1 if burst_index < remaining_count else 0)


## 先均分总数，再在批次间转移少量子弹，制造“有时密集、有时稀疏”的连发感觉。
## 每批至少保留一发，保证弹幕不会出现完全静止的空拍。
func _build_projectile_counts(projectile_total: int, burst_count: int) -> Array[int]:
	var safe_burst_count: int = maxi(burst_count, 1)
	var result: Array[int] = []
	for burst_index: int in range(safe_burst_count):
		result.append(_get_projectiles_in_burst(projectile_total, safe_burst_count, burst_index))

	if projectile_count_variation <= 0 or safe_burst_count <= 1:
		return result

	var transfer_rounds: int = int(round(float(safe_burst_count) * projectile_count_variation_strength))
	for _round: int in range(maxi(transfer_rounds, 1)):
		var source_index: int = randi_range(0, safe_burst_count - 1)
		var target_index: int = randi_range(0, safe_burst_count - 1)
		if source_index == target_index or result[source_index] <= 1:
			continue

		var transferable_count: int = mini(projectile_count_variation, result[source_index] - 1)
		var transfer_count: int = randi_range(1, transferable_count)
		result[source_index] -= transfer_count
		result[target_index] += transfer_count

	return result


## 以随机权重重分配原有等待总时长：节奏凌乱，但最后一批出现的时机保持和原本接近。
func _build_burst_intervals(burst_count: int, safe_interval: float) -> Array[float]:
	var interval_count: int = maxi(burst_count - 1, 0)
	return _build_randomized_intervals(interval_count + 1, safe_interval * float(interval_count))


## 按随机权重瓜分固定总时长。返回数组长度恒为 item_count - 1，适合作为相邻两发之间的等待表。
func _build_randomized_intervals(item_count: int, total_duration: float) -> Array[float]:
	var result: Array[float] = []
	var interval_count: int = maxi(item_count - 1, 0)
	if interval_count <= 0:
		return result

	var weights: Array[float] = []
	var total_weight: float = 0.0
	var safe_randomness: float = clampf(interval_randomness, 0.0, 0.9)
	for _index: int in range(interval_count):
		var weight: float = randf_range(1.0 - safe_randomness, 1.0 + safe_randomness)
		weights.append(weight)
		total_weight += weight

	for weight: float in weights:
		result.append(total_duration * (weight / total_weight))

	return result


func _spawn_burst(context: AbilityContext, projectile_count: int) -> void:
	if projectile_count <= 0 or context.caster == null:
		return

	var base_direction: Vector2 = _get_base_direction(context)
	for projectile_index: int in range(projectile_count):
		if not context.is_caster_action_valid():
			return

		var direction: Vector2 = _get_projectile_direction(base_direction, projectile_count, projectile_index)
		_spawn_one_projectile(context, direction)


func _spawn_one_projectile(context: AbilityContext, direction: Vector2, speed_multiplier: float = 1.0) -> void:
	var ability_manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if ability_manifest == null:
		return

	var caster: Entity = context.caster
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		ability_manifest.queue_free()
		return

	root.add_child(ability_manifest)
	ability_manifest.global_position = caster.global_position + direction * forward_offset
	if rotate_to_direction and direction != Vector2.ZERO:
		ability_manifest.global_rotation = direction.angle()
	if ability_manifest is ProjectileManifest:
		var projectile_manifest: ProjectileManifest = ability_manifest as ProjectileManifest
		projectile_manifest.source = caster
		projectile_manifest.speed *= speed_multiplier

	# 每发子弹拥有独立 Context，避免它们因共享方向或目标数组互相覆盖。
	var child_context: AbilityContext = AbilityContext.new(caster, context.ability)
	child_context.caster_action_version = context.caster_action_version
	child_context.locked_direction = direction
	child_context.targets = [ability_manifest.global_position + direction * projectile_target_distance]
	ability_manifest.activate(child_context)


func _get_base_direction(context: AbilityContext) -> Vector2:
	if context.locked_direction != Vector2.ZERO:
		return context.locked_direction.normalized()

	var facing_direction: Vector2 = context.caster.get_facing_direction()
	return facing_direction.normalized() if facing_direction != Vector2.ZERO else Vector2.RIGHT


func _get_projectile_direction(base_direction: Vector2, projectile_count: int, projectile_index: int) -> Vector2:
	var safe_base_direction: Vector2 = base_direction.normalized() if base_direction != Vector2.ZERO else Vector2.RIGHT
	var angle_offset: float = 0.0
	if projectile_count > 1:
		var progress: float = float(projectile_index) / float(projectile_count - 1)
		angle_offset = lerpf(-fan_angle_degrees * 0.5, fan_angle_degrees * 0.5, progress)
	if random_angle_jitter_degrees > 0.0:
		angle_offset += randf_range(-random_angle_jitter_degrees, random_angle_jitter_degrees)

	return safe_base_direction.rotated(deg_to_rad(angle_offset)).normalized()


## 逐发模式不再按索引均分扇形，而是在整段扇形内为每一发独立抽取方向。
func _get_random_fan_direction(base_direction: Vector2) -> Vector2:
	var safe_base_direction: Vector2 = base_direction.normalized() if base_direction != Vector2.ZERO else Vector2.RIGHT
	var angle_offset: float = randf_range(-fan_angle_degrees * 0.5, fan_angle_degrees * 0.5)
	if random_angle_jitter_degrees > 0.0:
		angle_offset += randf_range(-random_angle_jitter_degrees, random_angle_jitter_degrees)
	return safe_base_direction.rotated(deg_to_rad(angle_offset)).normalized()


## 每发单独随机飞行速度，让连续子弹在空中的前后距离不再完全一致。
func _get_random_speed_multiplier() -> float:
	var min_multiplier: float = minf(min_projectile_speed_multiplier, max_projectile_speed_multiplier)
	var max_multiplier: float = maxf(min_projectile_speed_multiplier, max_projectile_speed_multiplier)
	return randf_range(min_multiplier, max_multiplier)


func _count_ammo_relics(caster: Entity) -> int:
	if caster == null:
		return 0

	var inventory_value: Variant = caster.get("player_inventory")
	if not (inventory_value is Inventory):
		return 0

	var inventory: Inventory = inventory_value as Inventory
	var result: int = 0
	for slot_index: int in range(inventory.slots.size()):
		if not include_locked_inventory_slots and inventory.is_slot_locked_for_use(slot_index):
			continue

		var slot: Slot = inventory.slots[slot_index]
		if slot != null and _relic_has_ammo_tag(slot.item):
			result += 1

	return result


func _relic_has_ammo_tag(relic: Relic) -> bool:
	if relic == null:
		return false

	for raw_tag: RelicTag in relic.tags:
		if raw_tag == null:
			continue
		if ammo_tag != null:
			if raw_tag == ammo_tag:
				return true
			if not raw_tag.resource_path.is_empty() and raw_tag.resource_path == ammo_tag.resource_path:
				return true
		if ammo_tag_name != &"" and StringName(raw_tag.tag_name) == ammo_tag_name:
			return true

	return false
