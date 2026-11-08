class_name CreatureThreats
extends CrossingThreats
## The crossing's threats with a creature behind them (creatures-ai "Crossing reef shark"): a rock
## hits the vessel; a shark pass is a reef shark that takes a swimmer who meets its strike
## conditions, else an intact vessel, else nobody, then circles for its circle time and leaves.
## The crossing's own numbers (`bite_swimmer`, `hit_vessel`) are unchanged.

const SHARK_ID: StringName = &"reef_shark"
const SHARK_OFFSET_PX: Vector2 = Vector2(16.0, 0.0)


func resolve(event: CrossingBeat, crossing: Crossing) -> void:
	match event.kind:
		CrossingBeat.Kind.ROCK:
			crossing.hit_vessel(crossing.tuning.rock_hit)
		CrossingBeat.Kind.SHARK_PASS:
			_shark_pass(crossing)


func _shark_pass(crossing: Crossing) -> void:
	var data := GameState.content.get_entry(&"creatures", SHARK_ID) as CreatureData
	var arrives_at: Vector2 = crossing.deck_center()
	var bitten: bool = false
	for peer: int in crossing.peers():
		if crossing.rider_state(peer) != Crossing.Rider.IN_WATER:
			continue
		var body := crossing.body_of(peer)
		if PatrolCircleStrike.qualifies(body, data):
			crossing.bite_swimmer(peer, data.id)
			arrives_at = body.global_position
			bitten = true
			break
	if not bitten:
		crossing.hit_vessel(crossing.tuning.shark_hit)
	_show_shark(crossing, data, arrives_at + SHARK_OFFSET_PX)


# The visual shark: it appears beside the victim, circles for its circle time and frees itself.
# It comes through the session's entity spawner like the island's creatures, so every peer sees it
# (and a peer that joins during the circle); only the host times it (crossing-shark-sync).
func _show_shark(crossing: Crossing, data: CreatureData, at: Vector2) -> void:
	var session := crossing.session()
	if session == null:
		return
	var shark := session.spawn_creature(data, at)
	if shark != null:
		shark.lifetime_s = data.circle_time_s.x
