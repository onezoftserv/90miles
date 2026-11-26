class_name RaftRecord
extends RefCounted
## A raft's state as it rides from one beach to the next (island-stop D6, crossing "Fittings ride
## with the raft"): its integrity, its maximum (the recipe's integrity plus its fittings' bonuses)
## and the recipe ids of its fittings. It replaces the float that used to travel in IslandRoutes'
## departures, the crossing result, `travel_to`, the join extras and the crossing snapshot. The
## fittings' effects at sea are read from their recipes' `vessel_modifiers`, so a new fitting whose
## effects use existing stats is a data file.

const RAFT_RECIPE_ID: StringName = &"raft"
## A record takes at most this many fittings, whatever a forged message says (and so a beached Raft).
const MAX_FITTINGS: int = 8

var integrity: float = 0.0
var maximum: float = 0.0
var fittings: Array[StringName] = []


## A raft at `at` with no fittings, its maximum the raft recipe's integrity (100) unless given.
static func bare(at: float, top: float = -1.0) -> RaftRecord:
	var record := RaftRecord.new()
	if top <= 0.0:
		var recipe := GameState.content.get_entry(&"recipes", RAFT_RECIPE_ID) as RecipeData
		top = recipe.vessel_integrity if recipe != null else 100.0
	record.maximum = top
	record.integrity = clampf(at, 0.0, top)
	return record


## The state of the raft `raft` lying on the beach.
static func of_raft(raft: Raft) -> RaftRecord:
	var record := RaftRecord.new()
	record.integrity = raft.integrity
	record.maximum = raft.max_integrity
	record.fittings = raft.fittings.duplicate()
	return record


## Plain containers only, so nothing depends on how typed ones travel.
func to_dict() -> Dictionary:
	var names: Array = []
	for id: StringName in fittings:
		names.append(String(id))
	return {"integrity": integrity, "max": maximum, "fittings": names}


## Null for anything not shaped like a record (a peer never trusts what arrives): not a dictionary,
## an integrity or maximum that is not a finite number, a maximum of 0 or less, or fittings that are
## not a list. The integrity is clamped to 0..maximum, and only fittings the catalog knows as
## vessel upgrades are kept, each once, at most MAX_FITTINGS.
static func from_dict(data: Variant) -> RaftRecord:
	if not data is Dictionary:
		return null
	var raw: Dictionary = data
	var raw_integrity: Variant = raw.get("integrity")
	var raw_max: Variant = raw.get("max")
	var raw_fittings: Variant = raw.get("fittings")
	if not (raw_integrity is float or raw_integrity is int) or not (raw_max is float or raw_max is int):
		return null
	if not is_finite(float(raw_integrity)) or not is_finite(float(raw_max)) or float(raw_max) <= 0.0:
		return null
	if not raw_fittings is Array:
		return null
	var record := RaftRecord.new()
	record.maximum = float(raw_max)
	record.integrity = clampf(float(raw_integrity), 0.0, record.maximum)
	record.fittings = checked_fittings(raw_fittings)
	return record


## The fittings in `raw` the catalog knows as vessel upgrades, each once, at most MAX_FITTINGS.
static func checked_fittings(raw: Array) -> Array[StringName]:
	var kept: Array[StringName] = []
	for entry: Variant in raw.slice(0, MAX_FITTINGS):
		if not (entry is StringName or entry is String):
			continue
		var fitting := GameState.content.get_entry(&"recipes", StringName(entry)) as RecipeData
		if fitting != null and fitting.output_kind == RecipeData.OutputKind.VESSEL_UPGRADE and not kept.has(fitting.id):
			kept.append(fitting.id)
	return kept


func has_fitting(id: StringName) -> bool:
	return fittings.has(id)


## `base` with every fitting's vessel modifier on `stat` applied, in fitting order (MULTIPLY,
## ADD, then SET as each comes).
func apply(stat: ModifierData.Stat, base: float) -> float:
	var out: float = base
	for id: StringName in fittings:
		var fitting := GameState.content.get_entry(&"recipes", id) as RecipeData
		if fitting == null:
			continue
		for modifier: ModifierData in fitting.vessel_modifiers:
			if modifier == null or modifier.stat != stat or modifier.scope != ModifierData.Scope.VESSEL:
				continue
			match modifier.op:
				ModifierData.Op.MULTIPLY:
					out *= modifier.value
				ModifierData.Op.ADD:
					out += modifier.value
				ModifierData.Op.SET:
					out = modifier.value
	return out


## What a rock or a debris takes off this raft instead of `amount` (crossing "Defensas at sea").
func hazard_damage(amount: float) -> float:
	return maxf(apply(ModifierData.Stat.VESSEL_HAZARD_DAMAGE, amount), 0.0)


## True when the deck is shade for riders aboard (crossing "Toldo at sea").
func deck_shaded() -> bool:
	return apply(ModifierData.Stat.VESSEL_DECK_SHADE, 0.0) >= 1.0

