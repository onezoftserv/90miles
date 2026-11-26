class_name CreatureThreats
extends CrossingThreats
## The crossing's threats with a creature behind them (creatures-ai "Crossing reef shark"): a rock
## or debris hits the vessel where its lane overlaps it (crossing "Scrolling hazards"); a shark pass is a reef shark that takes a swimmer who meets its strike
## conditions, else an intact vessel, else nobody, then circles for its circle time and leaves.
## The crossing's own numbers (`bite_swimmer`, `hit_vessel`) are unchanged. The vessel hit is a
## shark's, so a route that dumps on a shark attack throws that vessel's riders in, and the shark
## shows beside the deck that was hit (vessel-car-board).
## crossing-gameplay: the shark comes at the pass's warning and circles its fin spot until the
## strike (creatures-ai "Crossing reef shark"); a shooed shark leaves at once.

const SHARK_ID: StringName = &"reef_shark"
const SHARK_OFFSET_PX: Vector2 = Vector2(16.0, 0.0)
## The fin's circle round its spot while it waits to strike.
const CIRCLE_RADIUS_PX: float = 4.0
const CIRCLE_RAD_PER_S: float = 3.0

# The shark of each warned pass, by the beat, with where its fin circles (keys typed with the base
# class: a typed container of CrossingBeat leaks at exit).
var _sharks: Dictionary[RefCounted, Creature] = {}
var _spots: Dictionary[RefCounted, Vector2] = {}
var _clock_s: float = 0.0


func warn(event: CrossingBeat, crossing: Crossing, spot: Vector2) -> void:
	var data := GameState.content.get_entry(&"creatures", SHARK_ID) as CreatureData
	var session := crossing.session()
	if data == null or session == null or _sharks.has(event):
		return
	var shark := session.spawn_creature(data, spot)
	if shark == null:
		return
	shark.lifetime_s = maxf(event.time_s - crossing.elapsed_s, 0.0) + data.circle_time_s.x + 1.0
	_sharks[event] = shark
	_spots[event] = spot


func shooed(event: CrossingBeat, _crossing: Crossing) -> void:
	var shark := _sharks.get(event) as Creature
	_sharks.erase(event)
	_spots.erase(event)
	if is_instance_valid(shark):
		shark.queue_free()


func tick(_crossing: Crossing, delta: float) -> void:
	_clock_s += delta
	for event: RefCounted in _spots:
		var shark := _sharks.get(event) as Creature
		if is_instance_valid(shark):
			shark.position = _spots[event] + Vector2(cos(_clock_s * CIRCLE_RAD_PER_S), sin(_clock_s * CIRCLE_RAD_PER_S)) * CIRCLE_RADIUS_PX


func resolve(event: CrossingBeat, crossing: Crossing) -> void:
	match event.kind:
		CrossingBeat.Kind.ROCK:
			if crossing.beat_hits_vessel(event):
				crossing.hit_vessel(crossing.hazard_damage(crossing.tuning.rock_hit))
		CrossingBeat.Kind.DEBRIS:
			if crossing.beat_hits_vessel(event):
				crossing.hole_vessel(event)
		CrossingBeat.Kind.SHARK_PASS:
			if not crossing.is_shooed(event):
				_shark_pass(crossing, event)


func _shark_pass(crossing: Crossing, event: CrossingBeat) -> void:
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
	var strikes_at: Vector2 = arrives_at + SHARK_OFFSET_PX
	if not bitten:
		var afloat: bool = crossing.integrity.intact()
		for board: VesselIntegrity in crossing.boards.values():
			afloat = afloat or board.intact()
		arrives_at = crossing.hit_vessel(crossing.tuning.shark_hit, true)
		# A vessel strike lands 1 tile off the hit deck's edge on the pass's side, never on the planks.
		strikes_at = crossing.strike_spot(event, arrives_at) if afloat else arrives_at + SHARK_OFFSET_PX
	# The warned shark stops circling its spot and goes beside its victim; one never warned (a
	# restored crossing past its warning) comes now.
	_spots.erase(event)
	var waiting := _sharks.get(event) as Creature
	_sharks.erase(event)
	if is_instance_valid(waiting) and data != null:
		waiting.position = strikes_at
		waiting.lifetime_s = data.circle_time_s.x
		return
	_show_shark(crossing, data, strikes_at)


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
