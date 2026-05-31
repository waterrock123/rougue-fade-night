## 获得遗物时额外获得一件指定遗物。
## 支持用 uid/path 延迟加载，避免两个遗物资源互相 ExtResource 造成循环解析。
class_name GainSpecificRelicEffect
extends RelicEffect


## 直接拖资源也可以，但如果目标资源会反向引用当前资源，推荐改填 relic_uid_or_path。
@export var relic_to_gain: Relic
## 推荐填写 uid://...，也可以填写 res://... 路径。
@export var relic_uid_or_path: String = ""
@export var only_when_levelup: bool = true


func on_gain(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null:
		return
	if only_when_levelup and (relic_context.own_relic == null or relic_context.own_relic.leveltip != Relic.LevelTip.LEVELUP):
		return

	var target_relic := _get_relic_to_gain()
	if target_relic == null:
		return

	var player_build := _get_player_build(relic_context)
	if player_build == null:
		return

	player_build.add_relic(target_relic.duplicate(true) as Relic)


func _get_relic_to_gain() -> Relic:
	if relic_to_gain != null:
		return relic_to_gain
	if relic_uid_or_path.is_empty():
		return null

	var loaded_resource: Resource = ResourceLoader.load(relic_uid_or_path)
	return loaded_resource as Relic


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner != null and "run_stats" in relic_context.owner:
		var run_stats = relic_context.owner.run_stats
		return run_stats.player_build if run_stats != null else null
	if relic_context.owner is Entity:
		var stats_controller := (relic_context.owner as Entity).stats_controller
		return stats_controller.player_build if stats_controller != null else null
	return null
