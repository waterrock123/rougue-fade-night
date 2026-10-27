class_name TutorialChapterData
extends Resource

## 章节入口只记录场景路径，避免在大厅预加载整套教学场景。
@export var chapter_id: StringName
@export var title: String
@export_multiline var description: String
@export_file("*.tscn") var scene_path: String
