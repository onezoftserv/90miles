class_name Crossing
extends Node2D
## The crossing (crossing capability): a vertically scrolling sea with the vessel at its centre,
## entered by a started route's riders. The host owns it: it rolls nothing here (the plan comes in),
## advances the clock, fires the plan's events, throws riders in, drains and drowns swimmers and
## ends the crossing with a CrossingResult. Clients build the same node, receive the plan, the
## rider states and the result, and only show them. Coordinates are absolute: the node sits at
## (0, 0) and the sea at `origin`, far from the island, so riders keep their sync and meters.
## The sea and the deck are drawn by children, `Sea` (CrossingSea) at z -40 and `Deck` (CrossingDeck)
## and `Boards` (CrossingBoards) at z -20, because the node sorts at its own (0, 0) in the y-sorted
## session while its riders are far north of it (art-pass "Draw order by foot position", "Crossing
## look"; design.md T5, T18). They read the crossing every frame and only show; the crossing never
## names them, and freeing them changes nothing it does.
## A board route (vessel-car-board) gives each rider their own board, a 1x2-tile deck in a row
## through the sea's centre, beside a shared vessel of no integrity: `vessel_of` and `deck_rect_of`
## answer per rider, so the raft and the car keep their one shared deck and lashing unchanged.
## crossing-gameplay: riders paddle the vessel sideways (`steer`, a number: the deck never moves and
## the sea slides past it), and rocks and debris come down lanes from the north edge, hitting the
## vessel only where their lane overlaps it and cutting the swimmers they pass over.

## Host and clients: the crossing ended with this result.
signal ended(result: CrossingResult)

enum Rider {
	ABOARD,
	TIED,
	IN_WATER,
	DEAD,
}

const HOST_ID: int = 1
const TILE_PX: float = 16.0
const SEA_TILES: Vector2i = Vector2i(24, 22)
const DECK_TILES: Vector2i = Vector2i(4, 2)
## A board is one tile wide and two long, nose north (crossing "Per-rider boards").
const BOARD_TILES: Vector2i = Vector2i(1, 2)
## Boards stand in rider order this many tiles apart, centre to centre: a 2-tile gap between them.
const BOARD_STEP_TILES: int = 3
## Where the first crossing's sea starts; each later one sits one sea width to the right.
const ORIGIN_Y_PX: float = -4096.0
const ORIGIN_STEP_PX: float = 1024.0
const SPACING_PX: float = 8.0
## Just outside the deck edge: where a swimmer pushed off the deck ends up.
const EDGE_GAP_PX: float = 1.0
const RESYNC_S: float = 1.0
const EPSILON_S: float = 0.000001
const SESSION_SERIAL_META: StringName = &"crossing_serial"
## The highest crossing number a joiner accepts: far more than a run holds, and its sea stays where
## float positions are exact to a fraction of a pixel.
const MAX_SERIAL: int = 1023
## Paddle points sit this far inside each edge of the deck, and this far beside each side of a
## board's centre (crossing "Paddling").
const PADDLE_INSET_PX: float = 6.0
const BOARD_PADDLE_PX: float = 12.0
## The host sends the lateral position at most this often while it changes.
const STEER_SEND_S: float = 0.1
## A hazard passing a swimmer cuts them when the swimmer is this close to its rect.
const CUT_SLACK_PX: float = 4.0
const SCENE: PackedScene = preload("res://scenes/crossing/crossing.tscn")

var route: RouteData
var plan: CrossingPlan
var tuning: CrossingTuning = CrossingTuning.standard()
var integrity: VesselIntegrity = VesselIntegrity.new()
## Board routes: each rider's own board by peer (crossing "Per-rider boards"); empty otherwise.
var boards: Dictionary[int, VesselIntegrity] = {}
## Replaceable: the reef shark (creatures-ai) resolves the shark pass; ScriptedThreats stays as the fallback.
var threats: CrossingThreats = CreatureThreats.new()
var elapsed_s: float = 0.0
var finished: bool = false
var result: CrossingResult
var sea: GridTerrain = GridTerrain.new()
var origin: Vector2 = Vector2.ZERO
## The crossing's number in its session: its node name and where its sea lies.
var serial: int = 0
## The vessel's lateral position and its paddlers (crossing "Paddling").
var steer: CrossingSteer = CrossingSteer.new()

var _session: CoopSession
## Host: the peers that have this crossing, so the only ones sent its messages (crossing-late-join).
var _recipients: Array[int] = []
var _peers: Array[int] = []
var _states: Dictionary[int, int] = {}
var _points: Dictionary[int, Interactable] = {}
var _lash: RescuePoint
var _dirty: bool = true
var _resync_left_s: float = 0.0
var _scroll_px: float = 0.0
# Events up to this time have fired (a hair past the clock, so 0.1 s steps meet exact times).
var _fired_to_s: float = -1.0
# Host: the rider slot the next single-board hit starts looking from (crossing "Board hits").
var _board_turn: int = 0
var _paddles: Array[RescuePoint] = []
var _steer_send_left_s: float = 0.0
var _steer_sent: float = 0.0
# Host: beat index -> the peers that beat already cut (each hazard cuts a swimmer once).
var _cut: Dictionary[int, Array] = {}


## Builds the crossing for `peer_ids` under `session`. The host rolls and sends the plan; a client
## waits for it. Called on every peer when `IslandRoutes.route_started` fires.
static func launch(session: CoopSession, started: RouteData, peer_ids: Array[int], starting_integrity: float, band: DataEnums.DistanceBand, rng: RandomNumberGenerator) -> Crossing:
	var number: int = next_serial(session)
	session.set_meta(SESSION_SERIAL_META, number + 1)
	var crossing := SCENE.instantiate() as Crossing
	crossing.name = node_name_for(number)
	session.add_child(crossing)
	var rolled: CrossingPlan = null
	if session.multiplayer.is_server():
		rolled = CrossingPlan.roll(started, band, WeatherManager.sky, rng, crossing.tuning, peer_ids.size())
	crossing.setup(session, started, peer_ids, starting_integrity, rolled, number)
	if rolled != null:
		# Every peer in the run heard the route start just before, so it has this crossing. A peer
		# still joining gets the snapshot once its join is answered (IslandRoutes.send_progress).
		for peer: int in session.multiplayer.get_peers():
			if session.roster.has(peer):
				crossing.share_with(peer)
		for peer: int in crossing._connected_recipients():
			crossing.receive_plan.rpc_id(peer, rolled.to_array(), crossing.integrity.value)
	return crossing


## A joiner (crossing-late-join): builds the crossing under way that `snapshot` describes, or
## refreshes it when this peer already has it. Rolls and replays nothing: the plan's beats up to
## the snapshot's time count as fired. Null without a snapshot or its route.
static func restore(session: CoopSession, snapshot: CrossingSnapshot) -> Crossing:
	if snapshot == null:
		return null
	var crossing := session.get_node_or_null(NodePath(node_name_for(snapshot.serial))) as Crossing
	if crossing == null:
		var started := GameState.content.get_entry(&"routes", snapshot.route_id) as RouteData
		if started == null:
			return null
		crossing = SCENE.instantiate() as Crossing
		crossing.name = node_name_for(snapshot.serial)
		session.add_child(crossing)
		crossing.setup(session, started, snapshot.riders, snapshot.maximum, snapshot.plan, snapshot.serial)
		crossing._fired_to_s = snapshot.elapsed_s + EPSILON_S
	crossing.apply_snapshot(snapshot)
	return crossing


## Host: the crossings under way in `session` (not ended, with a plan), oldest first.
static func under_way(session: CoopSession) -> Array[Crossing]:
	var list: Array[Crossing] = []
	for child: Node in session.get_children():
		var crossing := child as Crossing
		if crossing != null and not crossing.finished and crossing.plan != null and not crossing.is_queued_for_deletion():
			list.append(crossing)
	return list


## The number the next crossing launched in `session` gets.
static func next_serial(session: CoopSession) -> int:
	return session.get_meta(SESSION_SERIAL_META, 0)


## A joiner: takes the host's next crossing number, so a route started later gets the same node
## name on every peer. The counter never moves down.
static func follow_serial(session: CoopSession, host_next: int) -> void:
	session.set_meta(SESSION_SERIAL_META, maxi(next_serial(session), host_next))


static func node_name_for(number: int) -> String:
	return "Crossing%d" % number


func setup(session: CoopSession, started: RouteData, peer_ids: Array[int], starting_integrity: float, rolled: CrossingPlan, number: int) -> void:
	_session = session
	route = started
	plan = rolled
	_peers = peer_ids.duplicate()
	serial = number
	origin = Vector2(number * ORIGIN_STEP_PX, ORIGIN_Y_PX)
	# Swimmers and board riders share no vessel: the shared one has no integrity, so no deck or lashing.
	var shared: bool = not route.riders_swim and not is_board_route()
	var starting: float = 0.0 if not shared else (starting_integrity if starting_integrity > 0.0 else float(route.vessel_integrity))
	integrity = VesselIntegrity.create(starting)
	integrity.broke.connect(_on_broke)
	session.player_rebound.connect(_on_player_rebound)
	sea.default_terrain = DataEnums.Terrain.DEEP
	sea.current = Vector2.ZERO
	if integrity.intact():
		sea.fill_rect(_deck_cells(), DataEnums.Terrain.BEACH)
		_lash = _make_point(RescuePoint.Kind.LASH, 0, tuning.tie_hold_s)
	if is_board_route():
		for index: int in _peers.size():
			_add_board(_peers[index], index)
	_make_paddles()
	for index: int in _peers.size():
		_enter_rider(_peers[index], index)


func peers() -> Array[int]:
	return _peers


## Host: the peers that have this crossing and get its plan, states and result.
func recipients() -> Array[int]:
	return _recipients


## Host: `peer` has this crossing (it heard the route start, or was sent the snapshot) and gets its
## messages from now on.
func share_with(peer: int) -> void:
	if not _recipients.has(peer):
		_recipients.append(peer)


## The session this crossing runs in (its threats spawn through it), or null once it is gone.
func session() -> CoopSession:
	return _session if is_instance_valid(_session) else null


func body_of(peer: int) -> PlayerBody:
	return _session.body(peer) if is_instance_valid(_session) else null


## The peer `player` plays under, or 0 (coop-reconnect: never the node name, which a reclaimed
## body keeps from its first peer).
func peer_of(player: PlayerBody) -> int:
	return _session.peer_of(player) if is_instance_valid(_session) else 0


func rider_state(peer: int) -> Rider:
	return _states.get(peer, Rider.DEAD) as Rider


## True on a route whose riders each ride their own board (vessel-car-board).
func is_board_route() -> bool:
	return route != null and route.vessel == DataEnums.Vessel.BOARD and not route.riders_swim


## The vessel `peer` rides: their own board on a board route, the shared vessel otherwise.
func vessel_of(peer: int) -> VesselIntegrity:
	if is_board_route():
		return boards.get(peer, integrity) as VesselIntegrity
	return integrity


## The deck `peer` stands on: their own board on a board route, the shared deck otherwise.
func deck_rect_of(peer: int) -> Rect2:
	if is_board_route():
		return _board_rect(maxi(_peers.find(peer), 0))
	return deck_rect()


## The centre of the deck, or of the sea when swimmers have no vessel.
func deck_center() -> Vector2:
	return origin + Vector2(SEA_TILES) * TILE_PX * 0.5


func deck_rect() -> Rect2:
	var size := Vector2(DECK_TILES) * TILE_PX
	return Rect2(deck_center() - size * 0.5, size)


func sea_rect() -> Rect2:
	return Rect2(origin, Vector2(SEA_TILES) * TILE_PX)


## How far the sea has scrolled past the vessel, in px, wrapping at two lengths of the 32 px water
## texture (design.md T18). Read-only: the crossing's sea look follows it.
func scroll_px() -> float:
	return _scroll_px


## Host: advances the crossing by `delta` seconds (the body of `_physics_process`).
func advance(delta: float) -> void:
	if finished or plan == null or not multiplayer.is_server():
		return
	elapsed_s += delta
	steer.step(delta, tuning, _active_paddlers(), in_blow())
	var reached_s: float = elapsed_s + EPSILON_S
	for item: RefCounted in plan.due(_fired_to_s, reached_s):
		_fire(item as CrossingBeat)
	_fired_to_s = reached_s
	for peer: int in _peers:
		_tick_rider(peer, delta)
	_cut_swimmers()
	_refresh_points()
	if elapsed_s >= plan.length_s - EPSILON_S:
		_finish()
		return
	_resync_left_s -= delta
	if _dirty or _resync_left_s <= 0.0:
		_send_state()
	_send_steer(delta)


## The vessel takes a hit; at 0 it breaks (`_on_broke`). Nothing happens without a vessel. On a
## board route the hit takes one board: the next intact one in rider order from the last hit,
## wrapping round (crossing "Board hits"); with none left it hits nothing. A shark hit (`shark`) on a
## route that dumps on a shark attack throws the hit vessel's riders who are aboard and not tied into
## the water (crossing "Shark dumps"). Returns the centre of the deck that was hit, where the shark
## shows (the sea's centre when nothing was).
func hit_vessel(amount: float, shark: bool = false) -> Vector2:
	if not is_board_route():
		integrity.hit(amount)
		_dirty = true
		if shark:
			_shark_dump(_peers)
		return deck_center()
	var peer: int = _next_board()
	if peer == 0:
		return deck_center()
	var hit_at: Vector2 = deck_rect_of(peer).get_center()
	boards[peer].hit(amount)
	_dirty = true
	if shark:
		var riders: Array[int] = [peer]
		_shark_dump(riders)
	return hit_at


## Every vessel takes the hit at once (a squall): the shared one, or every intact board.
func hit_every_vessel(amount: float) -> void:
	integrity.hit(amount)
	for peer: int in boards:
		boards[peer].hit(amount)
	_dirty = true


## Host: `peer` stops paddling (they let go of the paddle).
func stop_paddling(peer: int) -> void:
	steer.stop(peer)


## True during a squall's blow: the squall's hit and the seconds after it (crossing "Squall line on
## the crossing").
func in_blow() -> bool:
	if plan == null:
		return false
	var hit: float = plan.squall_hit_s()
	return hit >= 0.0 and elapsed_s >= hit - EPSILON_S and elapsed_s < hit + tuning.squall_blow_s


## How fast a lane beat comes down the sea, in px/s: from the sea's north edge to the deck's middle
## in the hazard lead time.
func beat_speed_px() -> float:
	return TILE_PX * SEA_TILES.y * 0.5 / tuning.hazard_lead_s


## Where a lane beat is now (session coordinates): its lane beside the vessel's lateral position,
## and its time to come measured up the sea from the deck's middle.
func beat_center(beat: CrossingBeat) -> Vector2:
	var x: float = deck_center().x + (beat.lane - steer.position) * TILE_PX
	var y: float = deck_center().y - (beat.time_s - elapsed_s) * beat_speed_px()
	return Vector2(x, y)


## The width in tiles of a lane beat: a rock, debris, or a flotsam piece (one tile).
func beat_width_tiles(beat: CrossingBeat) -> float:
	match beat.kind:
		CrossingBeat.Kind.ROCK:
			return tuning.rock_width_tiles
		CrossingBeat.Kind.DEBRIS:
			return tuning.debris_width_tiles
	return 1.0


## Whether a lane beat is still to be drawn: every rock and debris, and each flotsam piece nobody
## has taken.
func beat_shown(beat: CrossingBeat) -> bool:
	return beat.is_lane_beat()


## True while a lane beat is anywhere on the sea.
func beat_on_sea(beat: CrossingBeat) -> bool:
	var rect := sea_rect().grow(TILE_PX)
	return beat.is_lane_beat() and rect.has_point(beat_center(beat))


## The vessel's half width in tiles and its centre's offset east of the deck's centre in tiles: the
## shared deck, or the whole row of boards. Zero width with no vessel.
func vessel_span_tiles() -> Vector2:
	if is_board_route():
		var first := _board_rect(0)
		var last := _board_rect(maxi(_peers.size() - 1, 0))
		var centre_px: float = (first.position.x + last.end.x) * 0.5
		return Vector2((last.end.x - first.position.x) * 0.5 / TILE_PX, (centre_px - deck_center().x) / TILE_PX)
	if integrity.has_integrity():
		return Vector2(tuning.vessel_width_tiles * 0.5, 0.0)
	return Vector2.ZERO


## Host: whether the rock or debris `beat` hits the vessel at its time: its lane closer to the
## vessel's lateral position than their two half widths (crossing "Scrolling hazards"). False with
## no vessel left to hit.
func beat_hits_vessel(beat: CrossingBeat) -> bool:
	var span: Vector2 = vessel_span_tiles()
	if span.x <= 0.0:
		return false
	if is_board_route():
		var any_intact: bool = false
		for peer: int in boards:
			any_intact = any_intact or boards[peer].intact()
		if not any_intact:
			return false
	elif not integrity.intact():
		return false
	var centre: float = steer.position + span.y
	return absf(beat.lane - centre) < span.x + beat_width_tiles(beat) * 0.5 - EPSILON_S


## A shark's bite on a swimmer: health and bleeding. `by` is the biting creature's id, the cause
## of death if it kills.
func bite_swimmer(peer: int, by: StringName = CreatureThreats.SHARK_ID) -> void:
	var body := body_of(peer)
	if body == null:
		return
	body.meters.harm(tuning.shark_swimmer_damage, by)
	body.meters.set_status(DataEnums.Status.BLEEDING, true)


## A rider aboard goes into the water for 10 energy.
func throw_in(peer: int) -> void:
	var state: Rider = rider_state(peer)
	var body := body_of(peer)
	if body == null or (state != Rider.ABOARD and state != Rider.TIED):
		return
	_set_state(peer, Rider.IN_WATER)
	body.meters.spend_energy(tuning.fall_in_energy)


func tie(peer: int) -> void:
	if rider_state(peer) == Rider.ABOARD and integrity.intact():
		_set_state(peer, Rider.TIED)


func untie(peer: int) -> void:
	if rider_state(peer) == Rider.TIED:
		_set_state(peer, Rider.ABOARD)


## A swimmer climbs or is pulled onto their own deck: the shared one, or their own board. Nothing
## happens without that vessel intact.
func bring_aboard(peer: int) -> void:
	var body := body_of(peer)
	if body == null or rider_state(peer) != Rider.IN_WATER or not vessel_of(peer).intact():
		return
	body.global_position = _spot(_peers.find(peer))
	_set_state(peer, Rider.ABOARD)


## Clients: the plan and the vessel's starting integrity, rolled by the host.
@rpc("authority", "call_remote", "reliable")
func receive_plan(plan_data: Array, vessel_value: float) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or plan != null or not is_finite(vessel_value):
		return
	var received := CrossingPlan.from_array(plan_data)
	if received == null:
		return
	plan = received
	if integrity.has_integrity():
		integrity.value = clampf(vessel_value, 0.0, integrity.maximum)


## Clients: every rider's state, the vessel's integrity and every board's (peer -> value, a board
## route only), on change and every second.
@rpc("authority", "call_remote", "reliable")
func receive_state(states: Dictionary, vessel_value: float, time_s: float, board_values: Dictionary = {}, play: Dictionary = {}) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or finished or not is_finite(vessel_value) or not is_finite(time_s):
		return
	_apply_state(states, vessel_value, time_s, board_values)
	apply_play(play)


## Clients: the vessel's lateral position and velocity as the host has it now, sent while it changes.
@rpc("authority", "call_remote", "unreliable_ordered")
func receive_steer(steer_data: Array, time_s: float) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or finished or not is_finite(time_s):
		return
	steer.read(steer_data, tuning)


## What the crossing's play state is now (crossing "Crossing play state on every peer"), as plain
## values: the lateral position.
func play_state() -> Dictionary:
	return {"steer": steer.to_array()}


## Clients and joiners: the host's play state; malformed parts are ignored.
func apply_play(play: Dictionary) -> void:
	if play.has("steer"):
		steer.read(play["steer"], tuning)


## Every board's integrity by rider, as plain values (empty off a board route).
func board_values() -> Dictionary:
	var values: Dictionary = {}
	for peer: int in boards:
		values[peer] = boards[peer].value
	return values


## A joiner: the crossing as `snapshot` has it (a checked snapshot, so no sender check here). The
## same state a resync brings, plus the plan if none came, the break, and every rider's body where
## the host has it, kept inside the sea.
func apply_snapshot(snapshot: CrossingSnapshot) -> void:
	if finished:
		return
	if plan == null:
		plan = snapshot.plan
	_apply_state(snapshot.states, snapshot.value, snapshot.elapsed_s, snapshot.boards)
	apply_play(snapshot.play)
	if snapshot.broken:
		_show_broken()
	var inside: Rect2 = sea_rect().grow(-EDGE_GAP_PX)
	for peer: int in _peers:
		var body := body_of(peer)
		if body == null:
			continue
		# Again, for a rider whose body was not under this peer yet when the crossing was built.
		_bind_body(body)
		if snapshot.positions.has(peer):
			body.global_position = snapshot.positions[peer].clamp(inside.position, inside.end)


## Clients: the crossing ended.
@rpc("authority", "call_remote", "reliable")
func receive_result(data: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or finished:
		return
	var received := CrossingResult.from_dict(data)
	if received == null:
		return
	finished = true
	result = received
	ended.emit(result)


func _physics_process(delta: float) -> void:
	advance(delta)


func _process(delta: float) -> void:
	_scroll_px = fmod(_scroll_px + tuning.scroll_tiles_per_s * TILE_PX * route.speed_multiplier * delta, TILE_PX * 4.0)
	# Clients run the host's clock and position forward between messages, so hazards slide smoothly.
	if plan != null and not finished and is_inside_tree() and not multiplayer.is_server():
		elapsed_s = minf(elapsed_s + delta, plan.length_s)
		steer.extrapolate(delta, tuning)

func _fire(event: CrossingBeat) -> void:
	match event.kind:
		CrossingBeat.Kind.SQUALL_WARN:
			var weather := WeatherManager.sky.weather
			if weather.pending == null and (weather.current == null or weather.current.id != &"squall"):
				weather.warn_weather(&"squall")
		CrossingBeat.Kind.SQUALL:
			_squall()
		_:
			threats.resolve(event, self)


# The squall hits the vessel, or every board, once and, on a route a squall dumps from, throws in
# every rider who is not tied down.
func _squall() -> void:
	hit_every_vessel(tuning.squall_hit * route.squall_damage_multiplier)
	if not route.dump_triggers.has(RouteData.DumpTrigger.SQUALL):
		return
	for peer: int in _peers:
		if rider_state(peer) == Rider.ABOARD:
			throw_in(peer)


# On a route a shark attack dumps from, `riders` aboard and not tied go into the water.
func _shark_dump(riders: Array[int]) -> void:
	if not route.dump_triggers.has(RouteData.DumpTrigger.SHARK_ATTACK):
		return
	for peer: int in riders:
		if rider_state(peer) == Rider.ABOARD:
			throw_in(peer)


# A broken vessel throws everyone in, the tied included, and nobody can climb back.
func _on_broke() -> void:
	_sink_deck()
	for peer: int in _peers:
		throw_in(peer)
	_dirty = true


# Clients: the host says the vessel broke; the deck's cells are deep water here too.
func _show_broken() -> void:
	if integrity.broken or not integrity.has_integrity():
		return
	integrity.broken = true
	_sink_deck()


func _sink_deck() -> void:
	sea.fill_rect(_deck_cells(), DataEnums.Terrain.DEEP)


func _add_board(peer: int, index: int) -> void:
	var board := VesselIntegrity.create(float(route.vessel_integrity))
	board.broke.connect(_on_board_broke.bind(board))
	boards[peer] = board
	if board.intact():
		sea.fill_rect(_board_cells(index), DataEnums.Terrain.BEACH)


# A broken board sinks and throws only its own rider in; nobody climbs back onto it.
func _on_board_broke(board: VesselIntegrity) -> void:
	var peer: int = _board_owner(board)
	if peer == 0:
		return
	_sink_board(peer)
	throw_in(peer)
	_dirty = true


# The rider whose board `board` is (it follows a rejoined rider to their new peer), or 0.
func _board_owner(board: VesselIntegrity) -> int:
	for peer: int in boards:
		if boards[peer] == board:
			return peer
	return 0


func _sink_board(peer: int) -> void:
	sea.fill_rect(_board_cells(maxi(_peers.find(peer), 0)), DataEnums.Terrain.DEEP)


# Clients: the host says this board broke; its cells are deep water here too.
func _show_board_broken(peer: int) -> void:
	var board := boards.get(peer) as VesselIntegrity
	if board == null or board.broken or not board.has_integrity():
		return
	board.broken = true
	_sink_board(peer)


# Host: the next intact board in rider order from the turn, wrapping round; 0 when none is left.
func _next_board() -> int:
	for step: int in _peers.size():
		var slot: int = (_board_turn + step) % _peers.size()
		var board := boards.get(_peers[slot]) as VesselIntegrity
		if board != null and board.intact():
			_board_turn = slot + 1
			return _peers[slot]
	return 0


func _tick_rider(peer: int, delta: float) -> void:
	var body := body_of(peer)
	if body == null:
		return
	if body.meters.dead:
		_set_state(peer, Rider.DEAD)
		return
	var state: Rider = rider_state(peer)
	if (state == Rider.ABOARD or state == Rider.TIED) and TerrainQuery.is_water(sea.terrain_at(body.cell())):
		throw_in(peer)
		state = rider_state(peer)
	if state == Rider.IN_WATER:
		_swim(body, delta)
	var inside: Rect2 = sea_rect().grow(-EDGE_GAP_PX)
	body.global_position = body.global_position.clamp(inside.position, inside.end)


# Keeping up with the vessel is swimming whether or not the rider moves; with no energy left the
# rider floats and drowns.
func _swim(body: PlayerBody, delta: float) -> void:
	body.meters.spend_energy(tuning.pace_drain_per_s * route.swim_drain_multiplier * delta)
	if body.meters.energy <= EPSILON_S:
		body.meters.harm(tuning.drown_health_per_s * delta, DeathCause.DROWNING)
	if integrity.intact() and deck_rect().has_point(body.global_position):
		body.global_position = _edge_outside(body.global_position, deck_rect())
	for peer: int in boards:
		var board := deck_rect_of(peer)
		if boards[peer].intact() and board.has_point(body.global_position):
			body.global_position = _edge_outside(body.global_position, board)


# A deck or board is not walkable from the water: a swimmer on it is moved to its nearest edge.
func _edge_outside(point: Vector2, deck: Rect2) -> Vector2:
	var gaps: Array[float] = [point.x - deck.position.x, deck.end.x - point.x, point.y - deck.position.y, deck.end.y - point.y]
	var nearest: int = gaps.find(gaps.min())
	match nearest:
		0:
			return Vector2(deck.position.x - EDGE_GAP_PX, point.y)
		1:
			return Vector2(deck.end.x + EDGE_GAP_PX, point.y)
		2:
			return Vector2(point.x, deck.position.y - EDGE_GAP_PX)
	return Vector2(point.x, deck.end.y + EDGE_GAP_PX)


func _enter_rider(peer: int, index: int) -> void:
	var aboard: bool = vessel_of(peer).has_integrity()
	_states[peer] = Rider.ABOARD if aboard else Rider.IN_WATER
	_points[peer * 2] = _make_point(RescuePoint.Kind.CLIMB, peer, tuning.climb_hold_s)
	_points[peer * 2 + 1] = _make_point(RescuePoint.Kind.PULL, peer, tuning.pull_hold_s)
	var body := body_of(peer)
	if body == null:
		return
	_bind_body(body)
	body.global_position = _spot(index) if aboard else deck_center() + Vector2(0.0, (index - 1.5) * SPACING_PX)
	_apply_flags()


# A rider's body swims on this sea, with its camera kept to it.
func _bind_body(body: PlayerBody) -> void:
	body.terrain = sea
	body.swim_energy_factor = 0.0
	var rect := sea_rect()
	body.camera.limit_left = int(rect.position.x)
	body.camera.limit_top = int(rect.position.y)
	body.camera.limit_right = int(rect.end.x)
	body.camera.limit_bottom = int(rect.end.y)


func _make_point(kind: RescuePoint.Kind, swimmer: int, hold_s: float) -> RescuePoint:
	var point := RescuePoint.new()
	point.kind = kind
	point.swimmer = swimmer
	point.crossing = self
	point.hold_time_s = hold_s
	point.enabled = kind == RescuePoint.Kind.LASH
	point.position = deck_center()
	# crossing "Which job a press takes": a swimmer to pull outranks flotsam, leaks and paddles.
	if kind == RescuePoint.Kind.PULL:
		point.priority = tuning.pull_priority
	point.interacted.connect(_on_point_used.bind(point))
	add_child(point)
	return point


func _on_point_used(by: Node, point: RescuePoint) -> void:
	if not multiplayer.is_server() or not by is PlayerBody:
		return
	var user: int = peer_of(by as PlayerBody)
	match point.kind:
		RescuePoint.Kind.LASH:
			if rider_state(user) == Rider.TIED:
				untie(user)
			else:
				tie(user)
		RescuePoint.Kind.PADDLE:
			if point.usable_by(by):
				steer.start(user, point.side)
		_:
			bring_aboard(point.swimmer)


# Climb points sit at the edge of the swimmer's own deck (the shared one, or their board) nearest
# them, pull handles on the swimmer; both are on only while the swimmer is in the water within 1
# tile and that vessel is intact.
func _refresh_points() -> void:
	if is_instance_valid(_lash):
		_lash.enabled = integrity.intact()
	for paddle: RescuePoint in _paddles:
		var vessel: VesselIntegrity = vessel_of(paddle.swimmer) if paddle.swimmer != 0 else integrity
		paddle.enabled = vessel.intact()
		if paddle.swimmer != 0:
			var board := deck_rect_of(paddle.swimmer)
			paddle.global_position = board.get_center() + Vector2(paddle.side * BOARD_PADDLE_PX, 0.0)
	var reach_px: float = tuning.reach_tiles * TILE_PX
	for peer: int in _peers:
		var body := body_of(peer)
		var climb := _points[peer * 2] as RescuePoint
		var pull := _points[peer * 2 + 1] as RescuePoint
		var deck := deck_rect_of(peer)
		var swimming: bool = body != null and rider_state(peer) == Rider.IN_WATER and vessel_of(peer).intact()
		climb.enabled = false
		pull.enabled = swimming
		if body == null:
			continue
		pull.global_position = body.global_position
		var edge: Vector2 = body.global_position.clamp(deck.position, deck.end)
		climb.global_position = edge
		climb.enabled = swimming and body.global_position.distance_to(edge) <= reach_px


# coop-reconnect: a rider who rejoined plays under a new peer, and their slot (so their deck spot),
# state and rescue points follow. Runs on every peer: the session re-binds on the host and, through
# `rebind_player`, on each client.
func _on_player_rebound(old_peer: int, new_peer: int, _body: PlayerBody) -> void:
	var slot: int = _peers.find(old_peer)
	if slot < 0:
		return
	_peers[slot] = new_peer
	if _states.has(old_peer):
		_states[new_peer] = _states[old_peer]
		_states.erase(old_peer)
	if boards.has(old_peer):
		boards[new_peer] = boards[old_peer]
		boards.erase(old_peer)
	if steer.paddlers.has(old_peer):
		steer.paddlers[new_peer] = steer.paddlers[old_peer]
		steer.paddlers.erase(old_peer)
	for paddle: RescuePoint in _paddles:
		if paddle.swimmer == old_peer:
			paddle.swimmer = new_peer
	for offset: int in 2:
		var point := _points.get(old_peer * 2 + offset) as RescuePoint
		_points.erase(old_peer * 2 + offset)
		if point != null:
			point.swimmer = new_peer
			_points[new_peer * 2 + offset] = point
	_dirty = true
	_apply_flags()


func _set_state(peer: int, state: Rider) -> void:
	if _states.get(peer) == state:
		return
	_states[peer] = state
	_dirty = true
	_apply_flags()


# Clients: the host's rider states (riders only, in range), clock, vessel and boards (riders'
# boards only, finite values, in range), from a resync or a snapshot.
func _apply_state(states: Dictionary, vessel_value: float, time_s: float, board_values: Dictionary = {}) -> void:
	for peer: Variant in states:
		var state: Variant = states[peer]
		if peer is int and state is int and _states.has(peer) and state >= 0 and state < Rider.size():
			_states[peer] = state
	elapsed_s = time_s
	if integrity.has_integrity():
		integrity.value = clampf(vessel_value, 0.0, integrity.maximum)
		if integrity.value <= 0.0:
			_show_broken()
	for peer: Variant in board_values:
		var value: Variant = board_values[peer]
		if not peer is int or not boards.has(peer) or not (value is float or value is int) or not is_finite(float(value)):
			continue
		var board: VesselIntegrity = boards[peer]
		board.value = clampf(float(value), 0.0, board.maximum)
		if board.value <= 0.0:
			_show_board_broken(peer)
	_apply_flags()


# Tied riders cannot move; every rider's swim drain is the crossing's, on every peer.
func _apply_flags() -> void:
	for peer: int in _peers:
		var body := body_of(peer)
		if body != null:
			body.pinned = rider_state(peer) == Rider.TIED
			body.swim_energy_factor = 0.0


# Host: the recipients still connected (a dropped peer is skipped; if it rejoins it is a new peer
# that gets the snapshot).
func _connected_recipients() -> Array[int]:
	var connected: PackedInt32Array = _session.multiplayer.get_peers() if is_instance_valid(_session) else PackedInt32Array()
	var list: Array[int] = []
	for peer: int in _recipients:
		if connected.has(peer):
			list.append(peer)
	return list


func _send_state() -> void:
	_dirty = false
	_resync_left_s = RESYNC_S
	for peer: int in _connected_recipients():
		receive_state.rpc_id(peer, _states.duplicate(), integrity.value, elapsed_s, board_values(), play_state())
	_steer_sent = steer.position


# Host: the lateral position to every recipient at most every STEER_SEND_S while it changes.
func _send_steer(delta: float) -> void:
	_steer_send_left_s -= delta
	if _steer_send_left_s > 0.0 or (steer.velocity == 0.0 and steer.position == _steer_sent):
		return
	_steer_send_left_s = STEER_SEND_S
	_steer_sent = steer.position
	for peer: int in _connected_recipients():
		receive_steer.rpc_id(peer, steer.to_array(), elapsed_s)


# Host: the riders whose paddling counts now: aboard and untied.
func _active_paddlers() -> Array[int]:
	var active: Array[int] = []
	for peer: int in steer.paddlers:
		if rider_state(peer) == Rider.ABOARD:
			active.append(peer)
	return active


# Two paddles on the shared deck, just inside its west and east edges; or two beside each board,
# for that board's rider. Swimmers' routes have none.
func _make_paddles() -> void:
	if is_board_route():
		for peer: int in _peers:
			for side: int in [CrossingSteer.WEST, CrossingSteer.EAST]:
				_paddles.append(_make_paddle(side, peer))
		return
	if not integrity.has_integrity():
		return
	for side: int in [CrossingSteer.WEST, CrossingSteer.EAST]:
		var paddle := _make_paddle(side, 0)
		paddle.position = deck_center() + Vector2(side * (DECK_TILES.x * TILE_PX * 0.5 - PADDLE_INSET_PX), 0.0)
		_paddles.append(paddle)


func _make_paddle(side: int, owner_peer: int) -> RescuePoint:
	var paddle := _make_point(RescuePoint.Kind.PADDLE, owner_peer, 0.0)
	paddle.side = side
	paddle.enabled = true
	if owner_peer != 0:
		paddle.position = deck_rect_of(owner_peer).get_center() + Vector2(side * BOARD_PADDLE_PX, 0.0)
	return paddle


# Host: each rock or debris on the sea cuts each swimmer it passes over, once (crossing "Hazards and
# swimmers"): a rock takes health and starts bleeding, debris takes less.
func _cut_swimmers() -> void:
	for index: int in plan.events.size():
		var beat := plan.events[index] as CrossingBeat
		if beat.kind != CrossingBeat.Kind.ROCK and beat.kind != CrossingBeat.Kind.DEBRIS:
			continue
		if absf(beat.time_s - elapsed_s) > tuning.hazard_lead_s + 1.0:
			continue
		var size := Vector2(beat_width_tiles(beat), 1.0) * TILE_PX
		var rect := Rect2(beat_center(beat) - size * 0.5, size).grow(CUT_SLACK_PX)
		for peer: int in _peers:
			if rider_state(peer) != Rider.IN_WATER:
				continue
			var body := body_of(peer)
			if body == null or body.meters.dead or not rect.has_point(body.global_position):
				continue
			var already: Array = _cut.get(index, [])
			if already.has(peer):
				continue
			already.append(peer)
			_cut[index] = already
			if beat.kind == CrossingBeat.Kind.ROCK:
				body.meters.harm(tuning.rock_cut_health, DeathCause.OTHER)
				body.meters.set_status(DataEnums.Status.BLEEDING, true)
			else:
				body.meters.harm(tuning.debris_cut_health, DeathCause.OTHER)


func _finish() -> void:
	finished = true
	result = CrossingResult.new()
	result.route_id = route.id
	result.integrity = integrity.value
	result.broken = integrity.broken
	for peer: int in _peers:
		var body := body_of(peer)
		var state: Rider = rider_state(peer)
		if body == null:
			continue
		result.riders[peer] = {
			"health": body.meters.health,
			"energy": body.meters.energy,
			"aboard": state == Rider.ABOARD or state == Rider.TIED,
			"dead": body.meters.dead,
		}
		if boards.has(peer):
			result.riders[peer]["board"] = boards[peer].value
			result.riders[peer]["board_broken"] = boards[peer].broken
		body.pinned = false
	for peer: int in _connected_recipients():
		receive_result.rpc_id(peer, result.to_dict())
	ended.emit(result)


func _deck_cells() -> Rect2i:
	var top_left := Vector2i((deck_rect().position / TILE_PX).floor())
	return Rect2i(top_left, DECK_TILES)


func _deck_spot(index: int) -> Vector2:
	return deck_center() + Vector2((index - 1.5) * SPACING_PX, 0.0)


# Where rider slot `index` stands aboard: the middle of their board, or their spot on the deck.
func _spot(index: int) -> Vector2:
	return _board_rect(index).get_center() if is_board_route() else _deck_spot(index)


# Board slot `index`: 1x2 tiles on the deck's rows, the row of boards centred on the sea.
func _board_cells(index: int) -> Rect2i:
	var span: int = BOARD_STEP_TILES * (_peers.size() - 1) + BOARD_TILES.x
	var first: int = floori((SEA_TILES.x - span) / 2.0)
	var top_left := Vector2i((origin / TILE_PX).floor()) + Vector2i(first + BOARD_STEP_TILES * index, 0)
	top_left.y = _deck_cells().position.y
	return Rect2i(top_left, BOARD_TILES)


func _board_rect(index: int) -> Rect2:
	var cells := _board_cells(index)
	return Rect2(Vector2(cells.position) * TILE_PX, Vector2(cells.size) * TILE_PX)
