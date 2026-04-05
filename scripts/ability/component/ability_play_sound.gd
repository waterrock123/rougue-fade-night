class_name AbilityPlaySound
extends AbilityComponent


@export var audio_config: AudiioConfig



func _activate(context: AbilityContext):
	AudioController.play(audio_config,context.caster.global_position)
	
	
