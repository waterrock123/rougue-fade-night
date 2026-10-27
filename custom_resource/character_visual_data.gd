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

@export_group("武器显示")
## 是否显示 Player 场景中的 Weapon 精灵。
@export var show_weapon: bool = false
## 武器贴图由角色视觉资源提供，避免在 Player 中写死角色判断。
@export var weapon_texture: Texture2D
## 武器相对角色中心的默认偏移。
@export var weapon_offset: Vector2 = Vector2.ZERO
@export var weapon_scale: Vector2 = Vector2.ONE
## 贴图默认朝向与游戏右方向不一致时使用的角度补偿，单位为弧度。
@export var weapon_rotation_offset: float = 0.0
## 开启后武器会实时指向鼠标世界坐标。
@export var weapon_tracks_mouse: bool = false
## 贴图默认枪口或剑尖是否朝右，用于瞄准左侧时保持武器正立。
@export var weapon_points_right: bool = true
## 用于修正素材自身上下颠倒的问题，会与鼠标瞄准时的自动翻转叠加。
@export var weapon_base_flip_vertical: bool = false
## 武器相对角色精灵的绘制层级；正数会显示在角色前方。
@export var weapon_z_index: int = -1


## 检查视觉资源是否具备指定动画，方便 Player 做安全回退。
func has_animation(animation_name: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name)
