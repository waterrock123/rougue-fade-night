class_name MapRelicPickup
extends GoldenFlashPickup

## 预先指定奖励的地图装备掉落；沿用背包/合成/获得效果链，背包满时保留在地上。
func _ready() -> void:
	prepare_reward_on_ready = false
	lifetime = 0.0
	pickup_display_name = prepared_reward_relic.relic_name if prepared_reward_relic != null else "装备"
	var sprite: Sprite2D = get_node_or_null("VisualRoot/Sprite2D") as Sprite2D
	if sprite != null and prepared_reward_relic != null:
		sprite.texture = prepared_reward_relic.icon
		if sprite.texture != null:
			var size: Vector2 = sprite.texture.get_size()
			sprite.scale = Vector2.ONE * (24.0 / maxf(size.x, size.y))
	super._ready()


func _apply_pickup(_collector: Entity) -> void:
	var stats: RunStats = _get_run_stats()
	if stats == null or stats.player_build == null or prepared_reward_relic == null:
		collected_once = false
		delay_collection_for(1.0)
		return
	if not stats.player_build.add_relic(prepared_reward_relic):
		collected_once = false
		delay_collection_for(1.0)
		show_collected_tip("背包已满，装备保留在地上")
		return
	var relic: Relic = prepared_reward_relic
	prepared_reward_relic = null
	if trigger_gain_effects:
		relic.gain_relic(self, null, "map_relic_%d" % get_instance_id())
	show_collected_tip("获得了%s装备" % relic.relic_name)
	queue_free()
