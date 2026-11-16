class_name CrossingThreats
extends RefCounted
## The hook that resolves the crossing's shark passes, rocks and debris. This base does nothing;
## ScriptedThreats is the default. The creatures-ai change swaps `Crossing.threats` for a
## resolver that spawns a reef shark and ends in the same `hit_vessel` / `bite_swimmer` calls.
## crossing-gameplay: a shark pass is warned before it strikes (`warn`, at its time minus the shark
## lead) and can be shooed before it does (`shooed`); `tick` runs every host step.


func resolve(_event: CrossingBeat, _crossing: Crossing) -> void:
	pass


## The shark pass `event` is warned: its fin circles at `spot` until it strikes.
func warn(_event: CrossingBeat, _crossing: Crossing, _spot: Vector2) -> void:
	pass


## A rider shooed the shark pass `event` away before it struck.
func shooed(_event: CrossingBeat, _crossing: Crossing) -> void:
	pass


## Host: every step of the crossing.
func tick(_crossing: Crossing, _delta: float) -> void:
	pass
