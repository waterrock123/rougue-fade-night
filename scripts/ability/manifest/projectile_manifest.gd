class_name ProjectileManifest
extends AbilityManifest

@export_group("投射物物理属性")
#飞行速度
@export var speed = 10.0
#瞄准目标
@export var target_group: String
#最大距离
@export var max_distance = 1000.0
#是否旋转
@export var is_rotate = false
#撞击音效
@export var hit_sound: AudiioConfig
#旋转速度
@export var rotate_speed = 10.0
@export_group("效果属性")

@export var damage = 10.0
@export var is_penetrate = false

var current_dir = Vector2.ZERO
var current_distance = 0.0


func activate(context: AbilityContext):
	if context.targets.size() > 0:
		var target_pos = context.get_target_positon(0)
		current_dir = (target_pos - global_position).normalized()
		look_at(target_pos)
		
func _process(delta: float) -> void:
	var movement = current_dir * delta * speed
	current_distance += movement.length()
	global_position += current_dir * delta * speed
	if is_rotate:
		global_rotation += delta * rotate_speed 
	if current_distance >= max_distance:
		queue_free()
	
func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	
	if parent != null and parent.is_in_group(target_group):
		if parent is Entity:
			parent.apply_damage(damage)
			if hit_sound!=null: AudioController.play(hit_sound,global_position)
			if is_penetrate:
				return
			queue_free()
	
