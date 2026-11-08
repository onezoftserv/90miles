class_name CrossingRig
extends RefCounted
## Test helper (crossing): a session with 1 to 4 bodies and a Crossing on `route_id` with a plan
## the test writes, advanced by hand in 0.1 s steps so the times are exact.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const STEP_S: float = 0.1


## The crossing, with `players` riders (peer ids 1, 2, ...) and a plan of `length_s` and `beats`.
static func make(test: GutTest, route_id: StringName, players: int, integrity: float, length_s: float, beats: Array[RefCounted] = []) -> Crossing:
	var session := SESSION_SCENE.instantiate() as CoopSession
	test.add_child_autofree(session)
	session.start()
	var ids: Array[int] = [1]
	for id: int in range(2, players + 1):
		var body := CoopSession.PLAYER_SCENE.instantiate() as PlayerBody
		body.name = str(id)
		session.players.add_child(body)
		body.player_input.enabled = false
		session._bodies[id] = body
		ids.append(id)
	session.body(1).player_input.enabled = false
	var route := (GameState.content.get_entry(&"routes", route_id) as RouteData).duplicate() as RouteData
	var crossing := Crossing.SCENE.instantiate() as Crossing
	session.add_child(crossing)
	crossing.setup(session, route, ids, integrity, CrossingPlan.create(length_s, beats), 0)
	crossing.advance(0.0)
	return crossing


static func beat(at_s: float, kind: CrossingBeat.Kind) -> RefCounted:
	return CrossingBeat.create(at_s, kind)


## Advances the crossing `seconds` with every body idle.
static func run(crossing: Crossing, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		crossing.advance(STEP_S)
		for peer: int in crossing.peers():
			crossing.body_of(peer).advance(STEP_S)


## `body` holds interact for `seconds` while the crossing runs.
static func hold(crossing: Crossing, body: PlayerBody, seconds: float) -> void:
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	run(crossing, seconds)


## `body` lets go of interact for one step.
static func release(crossing: Crossing, body: PlayerBody) -> void:
	body.intent = MoveIntent.new()
	run(crossing, STEP_S)


## Puts `body` in the water `gap_px` beyond the deck's right edge.
static func put_beside_deck(crossing: Crossing, body: PlayerBody, gap_px: float) -> void:
	var deck := crossing.deck_rect()
	body.global_position = Vector2(deck.end.x + gap_px, deck.get_center().y)
