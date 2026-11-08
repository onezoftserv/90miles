class_name CrossingThreats
extends RefCounted
## The hook that resolves the crossing's shark passes and rocks. This base does nothing;
## ScriptedThreats is the default. The creatures-ai change swaps `Crossing.threats` for a
## resolver that spawns a reef shark and ends in the same `hit_vessel` / `bite_swimmer` calls.


func resolve(_event: CrossingBeat, _crossing: Crossing) -> void:
	pass
