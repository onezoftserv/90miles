class_name BuildStageData
extends DataPart
## One stage of a staged build-site recipe (crafting-inventory "Build stages", island-pressure D1):
## its name, the inputs it needs and its own work seconds. A recipe's stages run in order and add up
## to its inputs and its time (the content check holds them to that). Embedded in the recipe file.

## Spanish name, shown on the build site's prompt: "Amarrar las cámaras".
@export var name_es: String = ""
## English name.
@export var name_en: String = ""
## Item id -> count this stage needs, on top of every earlier stage's.
@export var inputs: Dictionary[StringName, int] = {}
## Work seconds at base speed.
@export var time_s: float = 0.0


## The name in `locale`: English when asked for and present, else Spanish.
func get_display_name(locale: String = "es") -> String:
	if locale.begins_with("en") and not name_en.is_empty():
		return name_en
	return name_es


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"inputs": &"items"}
