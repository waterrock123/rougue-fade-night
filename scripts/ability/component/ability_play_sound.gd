## 播放技能音效组件。释放技能时按配置播放一次音效，通常放在动画或伤害组件前后配合手感。
class_name AbilityPlaySound
extends AbilityComponent


@export var audio_config: AudiioConfig



func _activate(context: AbilityContext):
	AudioController.play(audio_config,context.caster.global_position)
	
	
