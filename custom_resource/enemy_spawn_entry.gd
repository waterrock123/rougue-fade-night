class_name EnemySpawnEntry
extends Resource

enum SpawnPositionMode {
	## 围绕玩家生成，适合普通小怪或持续增援。
	AROUND_PLAYER,
	## 围绕 EnemySpawner 所在节点生成，适合固定场地中心刷 Boss。
	AROUND_SPAWNER,
	## 在场景/生成器中心加一个固定偏移生成，适合把 Boss 放在特定方向。
	FIXED_OFFSET,
	## 按 marker_path 指向的 Node2D 位置生成，适合精确摆放 Boss 战站位。
	MARKER_NODE,
}

@export_group("敌人")
## 要生成的敌人场景。
@export var enemy_scene: PackedScene
## 这个条目一共生成几只。
@export var count: int = 1
## 每次生成几只。count=4、spawn_batch_size=2 表示分两批生成。
@export var spawn_batch_size: int = 1
## 两批之间的间隔。0 表示立即生成完这一条目。
@export var spawn_interval: float = 0.0
## 仅用于编辑器识别，例如 boss/minion/elite，不参与逻辑判断。
@export var spawn_role: StringName = &"normal"

@export_group("生成位置")
@export var spawn_position_mode: SpawnPositionMode = SpawnPositionMode.AROUND_PLAYER
## 生成半径。小于 0 时使用 EnemySpawner 的默认半径。
@export var min_spawn_radius: float = -1.0
## 生成半径。小于 0 时使用 EnemySpawner 的默认半径。
@export var max_spawn_radius: float = -1.0
## FIXED_OFFSET 时使用，也会叠加到 MARKER_NODE 的位置上方便微调。
@export var spawn_offset: Vector2 = Vector2.ZERO
## MARKER_NODE 时使用。优先从当前场景查找，找不到再从 EnemySpawner 查找。
@export var marker_path: NodePath


func is_valid_entry() -> bool:
	return enemy_scene != null and count > 0
