## 动画帧事件数据。配合 AbilityTriggerComponentsOnSpriteFrame 使用，用来配置“动画播放到第几帧时触发哪些组件”。
class_name AbilityAnimationFrameEvent
extends Resource

# 当动画播放到指定帧时，要触发哪些同级技能组件。
@export var frame: int = 0
@export var component_names: Array[String] = []
