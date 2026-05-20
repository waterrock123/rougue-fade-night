## 播放施法者的指定动画。常用于技能开始时播放攻击、施法、冲锋等高优先级动画。
class_name AbilityAnimationRunner
extends AbilityComponent

@export var animation_name: String

func _activate(context: AbilityContext):
		
		context.caster.play_animation(AnimationWrapper.new(animation_name,true))
	
	
