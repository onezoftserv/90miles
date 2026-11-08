class_name ScriptedThreats
extends CrossingThreats
## The crossing's own scripted threats (crossing "Shark pass event"): a rock hits the vessel; a
## shark pass takes a bleeding or tired swimmer first, then an intact vessel, else nobody.


func resolve(event: CrossingBeat, crossing: Crossing) -> void:
	match event.kind:
		CrossingBeat.Kind.ROCK:
			crossing.hit_vessel(crossing.tuning.rock_hit)
		CrossingBeat.Kind.SHARK_PASS:
			_shark_pass(crossing)


func _shark_pass(crossing: Crossing) -> void:
	for peer: int in crossing.peers():
		if crossing.rider_state(peer) != Crossing.Rider.IN_WATER:
			continue
		var meters := crossing.body_of(peer).meters
		if meters.has_status(DataEnums.Status.BLEEDING) or meters.energy < crossing.tuning.shark_energy_threshold:
			crossing.bite_swimmer(peer)
			return
	crossing.hit_vessel(crossing.tuning.shark_hit)
