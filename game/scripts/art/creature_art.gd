class_name CreatureArt
extends Resource
## Per-creature drawing data, keyed by creature id (design.md D16): res://assets/art/creatures/
## creature_art.tres. A creature with no entry is drawn with a default one (a small shadow under
## frames standing on its position), so a new creature needs only its file and its frames.

const STANDARD_PATH: String = "res://assets/art/creatures/creature_art.tres"
## The three facing variants that stand in for a plain `idle`.
const IDLE_VARIANTS: PackedStringArray = ["idle_down", "idle_up", "idle_side"]

## Creature id to its CreatureArtEntry (typed with the base class, as the credits are).
@export var entries: Dictionary[StringName, Resource] = {}


## The entry for `creature_id`, or a default one.
func entry(creature_id: StringName) -> CreatureArtEntry:
	var found := entries.get(creature_id) as CreatureArtEntry
	return found if found != null else CreatureArtEntry.new()


## What is wrong with a creature's frames (art-pass "Facing variants count as idle", "A boss proxy
## needs no frames"): a weather or crossing boss proxy needs none; any other creature needs frames
## with `idle` or all three `idle_<facing>` variants. Each problem names the creature.
static func frames_problems(data: CreatureData) -> PackedStringArray:
	var problems: PackedStringArray = []
	if data.boss_kind == CreatureData.BossKind.WEATHER or data.boss_kind == CreatureData.BossKind.CROSSING:
		return problems
	if data.sprite_frames == null:
		problems.append("%s has no sprite_frames" % data.id)
	elif not CreatureAnim.has_idle(data.sprite_frames.get_animation_names()):
		problems.append("%s has neither idle nor all of %s" % [data.id, ", ".join(IDLE_VARIANTS)])
	return problems
