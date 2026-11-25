class_name VesselFittings
extends RefCounted
## What a raft's fittings do (island-stop "Raft fittings", "Raft maximum and fittings at sea",
## "Defensas at sea", "Toldo at sea"): pure reads over the fittings' recipe ids, so the raft on the
## beach and the crossing at sea agree. A fitting is a VESSEL_UPGRADE recipe: its `integrity_delta`
## raises the maximum, and its vessel-scoped modifiers do the rest. A new fitting whose effects use
## these stats is a data file.

## A vessel takes at most this many fittings, whatever a message says.
const MAX: int = 8


## The fittings' recipes, in order, skipping any id that is not a fitting.
static func recipes(fittings: Array[StringName]) -> Array[RecipeData]:
	var found: Array[RecipeData] = []
	for id: StringName in fittings:
		var recipe := GameState.content.get_entry(&"recipes", id) as RecipeData
		if recipe != null and recipe.output_kind == RecipeData.OutputKind.VESSEL_UPGRADE:
			found.append(recipe)
	return found


## How much the fittings add to the maximum.
static func bonus(fittings: Array[StringName]) -> float:
	var total: float = 0.0
	for recipe: RecipeData in recipes(fittings):
		total += recipe.integrity_delta
	return total


## The product of every MULTIPLY modifier of `stat` the fittings carry (1 with none): the defensas'
## VESSEL_HAZARD_DAMAGE.
static func factor(fittings: Array[StringName], stat: ModifierData.Stat) -> float:
	var product: float = 1.0
	for recipe: RecipeData in recipes(fittings):
		for modifier: ModifierData in recipe.vessel_modifiers:
			if modifier != null and modifier.stat == stat and modifier.op == ModifierData.Op.MULTIPLY:
				product *= modifier.value
	return product


## Whether a fitting SETs `stat` to 1 or more: the toldo's VESSEL_DECK_SHADE.
static func has_flag(fittings: Array[StringName], stat: ModifierData.Stat) -> bool:
	for recipe: RecipeData in recipes(fittings):
		for modifier: ModifierData in recipe.vessel_modifiers:
			if modifier != null and modifier.stat == stat and modifier.op == ModifierData.Op.SET and modifier.value >= 1.0:
				return true
	return false


## Only the known fitting ids of `raw` (a message's list), at most `limit`, each once.
static func checked(raw: Variant, limit: int) -> Array[StringName]:
	var kept: Array[StringName] = []
	if not raw is Array:
		return kept
	for entry: Variant in (raw as Array).slice(0, limit):
		if entry is StringName or entry is String:
			var recipe := GameState.content.get_entry(&"recipes", StringName(entry)) as RecipeData
			if recipe != null and recipe.output_kind == RecipeData.OutputKind.VESSEL_UPGRADE and not kept.has(recipe.id):
				kept.append(recipe.id)
	return kept
