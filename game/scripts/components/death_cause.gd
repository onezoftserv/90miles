class_name DeathCause
extends RefCounted
## survival-meters "Cause ids": the ids a death can name, their Spanish labels and the cleaning of
## a cause that came over the network. Fixed ids cover what is not a creature; a creature's own
## CreatureData.id is its cause, so a new creature needs no script change. Never instantiated.

## Health lost while thirst is empty.
const THIRST: StringName = &"thirst"
## A swimmer with no energy left in a crossing.
const DROWNING: StringName = &"drowning"
## A player removed after their disconnect countdown (coop-networking).
const REMOVED: StringName = &"removed"
## Poison, item effects, and a death with no recorded cause.
const OTHER: StringName = &"other"
const FIXED: Array[StringName] = [THIRST, DROWNING, REMOVED, OTHER]
const LABELS: Dictionary[StringName, String] = {
	THIRST: "sed",
	DROWNING: "ahogamiento",
	REMOVED: "desconexión",
	OTHER: "causa desconocida",
}


## The recorded cause of a dead player's meters: empty while alive, `other` if none was recorded.
static func of(meters: SurvivalMeters) -> StringName:
	if not meters.dead:
		return &""
	return meters.death_cause if not meters.death_cause.is_empty() else OTHER


## The Spanish label of `cause`: a creature's name, a fixed id's label, anything else `other`'s.
static func label(cause: StringName, catalog: ContentCatalog) -> String:
	if LABELS.has(cause):
		return LABELS[cause]
	if catalog == null:
		return LABELS[OTHER]
	var creature := catalog.get_entry(&"creatures", cause) as CreatureData
	return creature.name_es if creature != null else LABELS[OTHER]


## `value` as a cause id if it is a fixed id or a creature in `catalog`, else `fallback`.
static func checked(value: Variant, catalog: ContentCatalog, fallback: StringName = OTHER) -> StringName:
	if not (value is StringName or value is String):
		return fallback
	var cause := StringName(value)
	if FIXED.has(cause):
		return cause
	if catalog != null and catalog.has_entry(&"creatures", cause):
		return cause
	return fallback
