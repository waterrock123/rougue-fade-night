class_name AbilitySpawnManifest
extends AbilityComponent

#生成对象场景
@export var manifest_scene: PackedScene#能力清单
@export var set_as_child = false
@export var spawn_offset: Vector2 =Vector2.ZERO
@export var scale_multiplier: float = 1.0

func _activate(context: AbilityContext):
	if manifest_scene == null: return
	
	var ability_manifest = manifest_scene.instantiate() as AbilityManifest
	var caster = context.caster
	#将场景实例化并添加到游玩场景中a
	if  set_as_child:
		caster.add_child(ability_manifest)
	else:
		var root=get_tree().get_root()
		ability_manifest.position=caster.position
		root.add_child(ability_manifest)
	
	
	ability_manifest.position+=spawn_offset
	ability_manifest.scale *= scale_multiplier
	ability_manifest.activate(context)
	
	
