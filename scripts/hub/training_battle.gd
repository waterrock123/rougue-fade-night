extends PlayScene

## 训练战斗复用技能和状态 UI，但不生成波次、随机物件或结算奖励。
func _initialize_battle_map() -> void:
	battle_map.refresh_layer_cache()
	battle_map.configure_depth_sorting()
	player.global_position = battle_map.get_player_spawn_position(player.global_position)
	_initialize_terrain_effect_controller()


func _handle_battle_completed(_skip_level_up: bool) -> void:
	pass


func _handle_game_over(_dead_player: Player) -> void:
	# 重建训练场，清理死亡前仍在运行的攻击、状态和召唤物。
	get_parent().get_parent().call_deferred("restart_training")
