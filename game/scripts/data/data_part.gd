class_name DataPart
extends Resource
## Base for values embedded inside content files (conditions, effects, spawn rules, quests,
## dialogue states...). Parts are inline sub-resources, not files, so they have no id or name.
## ContentValidator checks their references at any depth, so ids inside parts must exist too.


## Fields that hold ids of other content, as field name -> content type (folder name).
## May depend on the part's own settings (for example a condition's kind). Override per type.
func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {}
