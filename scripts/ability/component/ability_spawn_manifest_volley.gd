## 齐射生成组件：默认生成一枚投射物，每隔指定次数额外生成投射物。
## 组件只负责“生成几枚以及如何排布”，具体投射物伤害仍由 Manifest 自己负责。
class_name AbilitySpawnManifestVolley
extends AbilitySpawnManifest

@export_group("Volley")
## 每次基础生成的投射物数量。
@export var base_projectile_count: int = 1
## 奖励攻击额外生成的投射物数量。
@export var bonus_projectile_count: int = 1
## 连续完成多少次普通攻击后，让下一次攻击获得奖励投射物。
@export var attacks_before_bonus: int = 2
## 多枚投射物之间的横向间隔。
@export var side_spacing: float = 6.0
## 多枚投射物之间的角度展开范围。
@export var spread_angle_degrees: float = 3.0

var attacks_since_bonus: int = 0


func _activate(context: AbilityContext) -> void:
	if context == null or not context.is_caster_action_valid():
		return

	var shot_count: int = maxi(base_projectile_count, 1)
	if attacks_before_bonus > 0 and attacks_since_bonus >= attacks_before_bonus:
		shot_count += maxi(bonus_projectile_count, 0)
		attacks_since_bonus = 0
	else:
		attacks_since_bonus += 1

	var base_direction: Vector2 = context.locked_direction
	if base_direction == Vector2.ZERO:
		base_direction = context.caster.get_facing_direction()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT

	var previous_direction: Vector2 = context.locked_direction
	var previous_side_offset: float = side_offset
	var center_index: float = (float(shot_count) - 1.0) * 0.5

	for shot_index in range(shot_count):
		if not context.is_caster_action_valid():
			break

		var relative_index: float = float(shot_index) - center_index
		var angle_offset: float = deg_to_rad(relative_index * spread_angle_degrees)
		context.locked_direction = base_direction.rotated(angle_offset).normalized()
		side_offset = relative_index * side_spacing
		super._activate(context)

	context.locked_direction = previous_direction
	side_offset = previous_side_offset
