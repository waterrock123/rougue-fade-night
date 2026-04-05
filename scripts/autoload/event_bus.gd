
extends Node

#施法信号
signal play_cast_ability(ability: Ability)
#玩家生命值变化信号
signal player_health_changed(current_health: float,max_health:float)
#玩家能量变化信号
signal player_energy_changed(current_energy: float,max_energy:float)
