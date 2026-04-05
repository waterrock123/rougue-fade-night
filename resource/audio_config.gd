class_name AudiioConfig
extends Resource

@export var audio_streams: Array[AudioStream] = []
@export var volume_db = 0.0
@export var max_distance = 2000
@export var autoplay = false
@export var loop = false
@export var bus: StringName = "Master"
