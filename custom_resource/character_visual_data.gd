class_name CharacterVisualData
extends Resource

## 角色的运行时视觉配置。
## Character 只保存这份资源，Player 负责把它应用到 AnimatedSprite2D。

@export_group("动画资源")
## 当前角色使用的逐帧动画集合。动画名称需要遵守项目的通用动画约定。
@export var sprite_frames: SpriteFrames
## 角色进入场景后默认播放的动画。
@export var default_animation: StringName = &"idle"

@export_group("朝向与显示")
## 精灵原图默认是否朝左。关闭表示默认朝右。
@export var default_facing_left: bool = false
## 角色视觉缩放，不会改变实体碰撞体大小。
@export var visual_scale: Vector2 = Vector2.ONE
## 角色视觉偏移，不会改变实体根节点的位置。
@export var visual_offset: Vector2 = Vector2.ZERO


## 检查视觉资源是否具备指定动画，方便 Player 做安全回退。
func has_animation(animation_name: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name)
