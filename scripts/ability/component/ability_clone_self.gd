## 残影/分身视觉组件。根据施法者当前贴图生成若干残影，适合冲刺、闪避、快速移动等技能的表现。
class_name AbilityCloneSelf
extends AbilityComponent
#克隆残影数量
@export var number_of_clones = 3
@export var clone_delay = 0.05


func _activate(context: AbilityContext):
	var caster = context.caster
	var current_texture = caster.get_current_texture()
	
	for i in number_of_clones:
		await  get_tree().create_timer(clone_delay).timeout
		
		var clone = Sprite2D.new()
		clone.texture = current_texture
		clone.position = caster.position
		clone.modulate = Color(0.5,0.5,1,0.5)
		clone.z_index =caster.z_index - 1
		clone.flip_h = caster.animated_sprite.flip_h
		
		caster.get_parent().add_child(clone)
		
		var tween = create_tween()
		tween.tween_property(clone,"modulate:a",0.0,0.7)
		tween.tween_callback(clone.queue_free)
		
		
		
