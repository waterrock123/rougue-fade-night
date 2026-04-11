class_name Entity
#实体
extends Node2D

@export var max_health: float = 50.0
@export var max_energy: float = 50.0
@export var damage_text_color: Color = Color.WHITE

@export var energy_region_freq = 0.5
@export var energy_region_tick_value = 3

var current_anim: AnimationWrapper
var current_health: float
var current_energy: float
var is_dead: bool =false
var turning_cooldown = 0.0 
var energy_timer = 0.0 

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats_controller: StatsController = get_node_or_null("StatsController") as StatsController

func _ready() -> void:
	if stats_controller != null:
		current_health = stats_controller.current_health
		current_energy = stats_controller.current_energy
	else:
		current_health = max_health
		current_energy = max_energy
	animated_sprite.material = animated_sprite.material.duplicate()
	animated_sprite.animation_finished.connect(on_animation_finished)
	
	

func _exit_tree() -> void:
	animated_sprite.animation_finished.disconnect(on_animation_finished)

func apply_damage(damage: float):
	if is_dead: return
	
	current_health -= damage
	current_health = max(0,current_health)
	if stats_controller != null:
		stats_controller.current_health = current_health
	_show_damage_taken_effect()
	show_damage_popup(damage)
	_handle_damage_callback(damage)
	if current_health == 0:
		
		is_dead = true
		play_animation(AnimationWrapper.new("die",true))
		
		
func spend_energy(energy:float): pass


func apply_runtime_stats(_final_stats: Dictionary) -> void:
	pass


func play_animation(anim: AnimationWrapper):
	#阻止在播放动画时重新放重复动画
	if animated_sprite.animation == anim.name: return
	
	#防止低优先级动画覆盖最近的高优先级动画
	if(
		current_anim != null and current_anim.is_high_priority
		and not anim.is_high_priority
	): return
	
	
	
	current_anim = anim
	animated_sprite.play(anim.name)

func turn_to_position(pos: Vector2):
	if position.x > pos.x and not animated_sprite.flip_h:
		animated_sprite.flip_h = true
	elif position.x < pos.x and animated_sprite.flip_h:
		animated_sprite.flip_h =false

func on_animation_finished():
	current_anim = null

#获取高度函数
func get_height() ->float:
	var anim = animated_sprite.animation
	var frame_tex = animated_sprite.sprite_frames.get_frame_texture(anim,0)
	var height = frame_tex.get_height()
	return height*self.scale.y

#获取纹理
func get_current_texture() -> Texture2D:
	return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation,animated_sprite.frame)
	



#显示伤害提示
func show_damage_popup(damage: float):
	var height = get_height()
	var spawn_position = Vector2(position.x,position.y - (height * 0.5))
	FloatText.show_damage_text(str(int(damage)), spawn_position,damage_text_color)


func _handle_damage_callback(damage:float):
	pass


func _show_damage_taken_effect():
	if animated_sprite.material != null:
		for i in 2:
			animated_sprite.material.set_shader_parameter("is_hurt",true)
			await get_tree().create_timer(0.05).timeout
			animated_sprite.material.set_shader_parameter("is_hurt",false)
			await get_tree().create_timer(0.05).timeout
	
