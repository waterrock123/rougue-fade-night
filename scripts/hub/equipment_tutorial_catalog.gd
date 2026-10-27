class_name EquipmentTutorialCatalog
extends Resource

@export var lessons: Array[EquipmentTutorialLesson] = []
@export var fallback_lesson: EquipmentTutorialLesson


func resolve(character: Character) -> EquipmentTutorialLesson:
	for lesson: EquipmentTutorialLesson in lessons:
		if lesson != null and character != null and lesson.character_id == character.id:
			return lesson
	return fallback_lesson
