class_name HubNpcVisualData
extends Resource

## 大厅 NPC 的纯视觉配置，与交互功能分离，方便同一套 NPC 场景复用不同外观。

@export_group("动画资源")
@export var sprite_frames: SpriteFrames
@export var default_animation: StringName = &"idle"

@export_group("显示参数")
@export var default_facing_left: bool = false
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_offset: Vector2 = Vector2.ZERO
@export var visual_z_index: int = 0


func has_default_animation() -> bool:
	return sprite_frames != null and sprite_frames.has_animation(default_animation)
