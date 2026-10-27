class_name TutorialLessonCatalog
extends Resource

@export var lessons: Array[TutorialCharacterLesson] = []
## 新角色尚未配置专属教学时，借用通用指向技能，但不替换其基础攻击和外观。
@export var fallback_lesson: TutorialCharacterLesson


func resolve(character: Character) -> TutorialCharacterLesson:
	for lesson: TutorialCharacterLesson in lessons:
		if lesson != null and lesson.matches(character):
			return lesson
	return fallback_lesson
