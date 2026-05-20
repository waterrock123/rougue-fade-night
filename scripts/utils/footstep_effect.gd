class_name FootstepEffect
extends Node2D


@onready var feet_1 =$CPUParticles2D
@onready var feet_2 =$CPUParticles2D2

func  play():
	if !feet_1.emitting: feet_1.restart()
	await get_tree().create_timer(0.2).timeout
	if !feet_2.emitting: feet_2.restart()


func stop() -> void:
	if feet_1 != null:
		feet_1.emitting = false
	if feet_2 != null:
		feet_2.emitting = false
