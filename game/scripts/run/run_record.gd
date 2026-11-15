class_name RunRecord
extends RefCounted
## What the host remembers for one run (creature-perch-ride): the run's flags, how many of each
## creature the run has placed (`max_per_run`), and the day each limited effect last fired. Host
## only and never sent: flags are read by the host's endings, limits where effects apply. The
## session holds one, so a new run starts empty.

var flags: Dictionary[StringName, bool] = {}
var creature_counts: Dictionary[StringName, int] = {}
## Claim key to the day it was last claimed.
var claims: Dictionary[String, int] = {}


## Whether an effect limited by `limit` may fire for `key` on `day`; marks it fired if so.
## ONCE_PER_READER is once per run for its key (the key names the player).
func claim(key: String, limit: EffectData.Limit, day: int) -> bool:
	match limit:
		EffectData.Limit.NONE:
			return true
		EffectData.Limit.ONCE_PER_DAY:
			if claims.get(key, -1) == day:
				return false
		_:
			if claims.has(key):
				return false
	claims[key] = day
	return true


func set_flag(id: StringName) -> void:
	flags[id] = true


func clear_flag(id: StringName) -> void:
	flags.erase(id)


func has_flag(id: StringName) -> bool:
	return flags.get(id, false)


func count_creature(id: StringName) -> void:
	creature_counts[id] = creature_counts.get(id, 0) + 1


func creature_count(id: StringName) -> int:
	return creature_counts.get(id, 0)
