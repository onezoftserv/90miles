class_name ContentData
extends Resource
## Base for every content type in game/resources/ (content-data spec). A content file's id
## equals its file name, names are Spanish-first, and references to other content are ids.

@export var id: StringName = &""
@export var name_es: String = ""
@export var name_en: String = ""


## Player-visible name. English falls back to Spanish when it is empty.
func get_display_name(locale: String = "es") -> String:
	if locale.begins_with("en") and not name_en.is_empty():
		return name_en
	return name_es


## Fields that hold ids of other content, as field name -> content type (folder name).
## A field may be a StringName, an Array of ids, or a Dictionary keyed by id. Override per type.
func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {}


## Whether entries of this type have a player-visible name. Override to return false if not.
func requires_name() -> bool:
	return true
