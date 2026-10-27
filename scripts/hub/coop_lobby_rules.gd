## 双人等候室的协议与白名单。网络只传稳定ID及基础数据，不接收资源路径或Object。
@tool
class_name CoopLobbyRules
extends RefCounted

const PROTOCOL: int = 1
const MAX_PLAYERS: int = 2
const DEFAULT_PORT: int = 28080
const MOVE_SPEED: float = 150.0
const INPUT_TIMEOUT_MS: int = 350
const SYNC_SECONDS: float = 0.05
const BOUNDS: Rect2 = Rect2(-240, -140, 480, 280)
const CHARACTER_PATHS: Dictionary = {
	"warrior": "res://character_resource/warrior/warrior.tres",
	"scount": "res://character_resource/scount/scount.tres",
	"wizard": "res://character_resource/wizard/wizard.tres",
}


static func valid_character(id: String) -> bool:
	return CHARACTER_PATHS.has(id)


## 仅视觉端加载资源；协议层不依赖Character及其装备/存档类型链。
static func get_character(id: String) -> Resource:
	if not valid_character(id):
		return null
	return load(str(CHARACTER_PATHS[id])) as Resource


static func clean_name(value: String) -> String:
	var result: String = ""
	var trimmed: String = value.strip_edges()
	for index: int in range(trimmed.length()):
		var code: int = trimmed.unicode_at(index)
		if code >= 32 and code != 127:
			result += String.chr(code)
		if result.length() >= 20:
			break
	return result if not result.is_empty() else "旅人"


static func valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535


static func bounded_position(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, BOUNDS.position.x, BOUNDS.end.x), clampf(value.y, BOUNDS.position.y, BOUNDS.end.y))
