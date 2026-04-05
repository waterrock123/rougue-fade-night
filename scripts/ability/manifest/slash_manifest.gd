class_name SlashManifest
extends AbilityManifest

#交替攻击bool值
static var alternate_slash: bool=true
@export var rotation_offset: float = -90.0
@onready var animated_sprite: AnimatedSprite2D =$AnimatedSprite2D

var cloned_weapon: Node2D

func _activate(context: AbilityContext):
	var mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()
	look_at(mouse_pos)
	
	alternate_slash= !alternate_slash
	animated_sprite.flip_v=alternate_slash
	
	var weapon = context.caster.get_node("Weapon") as Node2D
	
	if weapon!=null:
		weapon.hide()
		var base_angle = (mouse_pos - context.caster.global_position).angle()
		var offset_rad = deg_to_rad(rotation_offset)
		
		if !alternate_slash:
			offset_rad = -offset_rad
		
		#克隆临时武器
		cloned_weapon = weapon.duplicate()
		cloned_weapon.show()
		context.caster.add_child(cloned_weapon)
		
		#武器的角度
		var weapon_angle = base_angle + offset_rad
		#武器指向的方向向量
		var weapon_direction = Vector2(cos(weapon_angle),sin(weapon_angle))
		
		cloned_weapon.global_position = context.caster.global_position +weapon_direction * 20.0
		
		cloned_weapon.rotation = weapon_angle + PI/2


func _process(delta: float) -> void:
	if animated_sprite.frame_progress >= 1.0:
		_finish_attack()
		
		
	
func _finish_attack():
	hide()
	if cloned_weapon:
		await  get_tree().create_timer(0.10).timeout
		cloned_weapon.queue_free()
	
	queue_free()
