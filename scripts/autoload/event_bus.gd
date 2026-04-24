
extends Node

#施法信号
signal play_cast_ability(ability: Ability)
#玩家生命值变化信号
signal player_health_changed(current_health: float,max_health:float)
#玩家能量变化信号
signal player_energy_changed(current_energy: float,max_energy:float)
#游戏暂停信号
signal game_paused(paused: bool)
#场景变更信号
signal  scene_changed(scene: String)
#打开背包信号 
signal change_bag()
#背包库存更新信号，背包库存数据发生变化时，发送这个信号，通知UI同步更新
signal inventory_update()
#装备更新信号，当装备栏数据发生变化时，发送这个信号，通知UI同步更新
signal equipment_update()
#商店库存更新信号，商店库存数据发生变化时，发送这个信号，通知UI同步更新
signal shop_inventory_update()
#玩家属性发生变更信号，发送这个信号，通知属性面板UI同步更新
signal attribute_update() 
#金币变化信号，发送这个信号通知UI同步更新
signal gold_changed()
#装备购买信号,传递这个装备
signal buy_equipment(equipment:Relic)


#退出地图信号，进入传入的房间的场景
signal map_exited(room: Room)
#离开事件房间信号，进入战斗
signal event_room_exited()
