class_name Crossing
extends Node2D
## The crossing (crossing capability): a vertically scrolling sea with the vessel at its centre,
## entered by a started route's riders. The host owns it: it rolls nothing here (the plan comes in),
## advances the clock, fires the plan's events, throws riders in, drains and drowns swimmers and
## ends the crossing with a CrossingResult. Clients build the same node, receive the plan, the
## rider states and the result, and only show them. Coordinates are absolute: the node sits at
## (0, 0) and the sea at `origin`, far from the island, so riders keep their sync and meters.

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
## Where the first crossing's sea starts; each later one sits one sea width to the right.
const ORIGIN_Y_PX: float = -4096.0
const ORIGIN_STEP_PX: float = 1024.0
const SPACING_PX: float = 8.0
## Just outside the deck edge: where a swimmer pushed off the deck ends up.
const EDGE_GAP_PX: float = 1.0
const RESYNC_S: float = 1.0
const EPSILON_S: float = 0.000001
const SESSION_SERIAL_META: StringName = &"crossing_serial"
const SCENE: PackedScene = preload("res://scenes/crossing/crossing.tscn")

var route: RouteData
var plan: CrossingPlan
var tuning: CrossingTuning = CrossingTuning.standard()
var integrity: VesselIntegrity = VesselIntegrity.new()
## Replaceable: creatures-ai puts the reef shark behind it.
var threats: CrossingThreats = ScriptedThreats.new()
var elapsed_s: float = 0.0
var finished: bool = false
var result: CrossingResult
var sea: GridTerrain = GridTerrain.new()
var origin: Vector2 = Vector2.ZERO
## The crossing's number in its session: its node name and where its sea lies.
var serial: int = 0

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
		rolled = CrossingPlan.roll(started, band, WeatherManager.sky, rng, crossing.tuning)
	crossing.setup(session, started, peer_ids, starting_integrity, rolled, number)
	if rolled != null:
		# Every peer connected now heard the route start just before, so it has this crossing.
		for peer: int in session.multiplayer.get_peers():
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
	var starting: float = 0.0 if route.riders_swim else (starting_integrity if starting_integrity > 0.0 else float(route.vessel_integrity))
	integrity = VesselIntegrity.create(starting)
	integrity.broke.connect(_on_broke)
	session.player_rebound.connect(_on_player_rebound)
	sea.default_terrain = DataEnums.Terrain.DEEP
	sea.current = Vector2.ZERO
	if integrity.intact():
		sea.fill_rect(_deck_cells(), DataEnums.Terrain.BEACH)
		_lash = _make_point(RescuePoint.Kind.LASH, 0, tuning.tie_hold_s)
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


func body_of(peer: int) -> PlayerBody:
	return _session.body(peer) if is_instance_valid(_session) else null


## The peer `player` plays under, or 0 (coop-reconnect: never the node name, which a reclaimed
## body keeps from its first peer).
func peer_of(player: PlayerBody) -> int:
	return _session.peer_of(player) if is_instance_valid(_session) else 0


func rider_state(peer: int) -> Rider:
	return _states.get(peer, Rider.DEAD) as Rider


## The centre of the deck, or of the sea when swimmers have no vessel.
func deck_center() -> Vector2:
	return origin + Vector2(SEA_TILES) * TILE_PX * 0.5


func deck_rect() -> Rect2:
	var size := Vector2(DECK_TILES) * TILE_PX
	return Rect2(deck_center() - size * 0.5, size)


func sea_rect() -> Rect2:
	return Rect2(origin, Vector2(SEA_TILES) * TILE_PX)


## Host: advances the crossing by `delta` seconds (the body of `_physics_process`).
func advance(delta: float) -> void:
	if finished or plan == null or not multiplayer.is_server():
		return
	elapsed_s += delta
	var reached_s: float = elapsed_s + EPSILON_S
	for item: RefCounted in plan.due(_fired_to_s, reached_s):
		_fire(item as CrossingBeat)
	_fired_to_s = reached_s
	for peer: int in _peers:
		_tick_rider(peer, delta)
	_refresh_points()
	if elapsed_s >= plan.length_s - EPSILON_S:
		_finish()
		return
	_resync_left_s -= delta
	if _dirty or _resync_left_s <= 0.0:
		_send_state()


## The vessel takes a hit; at 0 it breaks (`_on_broke`). Nothing happens without a vessel.
func hit_vessel(amount: float) -> void:
	integrity.hit(amount)
	_dirty = true


## A shark's bite on a swimmer: health and bleeding.
func bite_swimmer(peer: int) -> void:
	var body := body_of(peer)
	if body == null:
		return
	body.meters.add(DataEnums.Meter.HEALTH, -tuning.shark_swimmer_damage)
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


## A swimmer climbs or is pulled onto the deck. Nothing happens without an intact vessel.
func bring_aboard(peer: int) -> void:
	var body := body_of(peer)
	if body == null or rider_state(peer) != Rider.IN_WATER or not integrity.intact():
		return
	body.global_position = _deck_spot(_peers.find(peer))
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


## Clients: every rider's state and the vessel's integrity, on change and every second.
@rpc("authority", "call_remote", "reliable")
func receive_state(states: Dictionary, vessel_value: float, time_s: float) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or finished or not is_finite(vessel_value) or not is_finite(time_s):
		return
	_apply_state(states, vessel_value, time_s)


## A joiner: the crossing as `snapshot` has it (a checked snapshot, so no sender check here). The
## same state a resync brings, plus the plan if none came, the break, and every rider's body where
## the host has it, kept inside the sea.
func apply_snapshot(snapshot: CrossingSnapshot) -> void:
	if finished:
		return
	if plan == null:
		plan = snapshot.plan
	_apply_state(snapshot.states, snapshot.value, snapshot.elapsed_s)
	if snapshot.broken and integrity.has_integrity():
		integrity.broken = true
	var inside: Rect2 = sea_rect().grow(-EDGE_GAP_PX)
	for peer: int in snapshot.positions:
		var body := body_of(peer)
		if body != null and _peers.has(peer):
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
	queue_redraw()


func _draw() -> void:
	var rect := sea_rect()
	draw_rect(rect, Color(0.08, 0.28, 0.45))
	for row: int in range(-1, SEA_TILES.y / 4 + 1):
		var y: float = rect.position.y + row * TILE_PX * 4.0 + _scroll_px
		if y >= rect.position.y and y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.2, 0.45, 0.62), 1.0)
	if integrity.intact():
		var deck := deck_rect()
		draw_rect(deck, Color(0.55, 0.4, 0.22))
		draw_rect(deck, Color(0.3, 0.2, 0.1), false)


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


# The squall hits the vessel once and, on a route a squall dumps from, throws in every rider who
# is not tied down.
func _squall() -> void:
	hit_vessel(tuning.squall_hit * route.squall_damage_multiplier)
	if not route.dump_triggers.has(RouteData.DumpTrigger.SQUALL):
		return
	for peer: int in _peers:
		if rider_state(peer) == Rider.ABOARD:
			throw_in(peer)


# A broken vessel throws everyone in, the tied included, and nobody can climb back.
func _on_broke() -> void:
	sea.fill_rect(_deck_cells(), DataEnums.Terrain.DEEP)
	for peer: int in _peers:
		throw_in(peer)
	_dirty = true


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
		body.meters.add(DataEnums.Meter.HEALTH, -tuning.drown_health_per_s * delta)
	if integrity.intact() and deck_rect().has_point(body.global_position):
		body.global_position = _edge_outside(body.global_position)


# The deck is not walkable from the water: a swimmer on it is moved to the nearest edge.
func _edge_outside(point: Vector2) -> Vector2:
	var deck := deck_rect()
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
	_states[peer] = Rider.IN_WATER if not integrity.has_integrity() else Rider.ABOARD
	_points[peer * 2] = _make_point(RescuePoint.Kind.CLIMB, peer, tuning.climb_hold_s)
	_points[peer * 2 + 1] = _make_point(RescuePoint.Kind.PULL, peer, tuning.pull_hold_s)
	var body := body_of(peer)
	if body == null:
		return
	body.terrain = sea
	body.swim_energy_factor = 0.0
	body.global_position = _deck_spot(index) if integrity.has_integrity() else deck_center() + Vector2(0.0, (index - 1.5) * SPACING_PX)
	var rect := sea_rect()
	body.camera.limit_left = int(rect.position.x)
	body.camera.limit_top = int(rect.position.y)
	body.camera.limit_right = int(rect.end.x)
	body.camera.limit_bottom = int(rect.end.y)
	_apply_flags()


func _make_point(kind: RescuePoint.Kind, swimmer: int, hold_s: float) -> RescuePoint:
	var point := RescuePoint.new()
	point.kind = kind
	point.swimmer = swimmer
	point.crossing = self
	point.hold_time_s = hold_s
	point.enabled = kind == RescuePoint.Kind.LASH
	point.position = deck_center()
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
		_:
			bring_aboard(point.swimmer)


# Climb points sit at the deck edge nearest their swimmer, pull handles on the swimmer; both are on
# only while the swimmer is in the water within 1 tile and the vessel is intact.
func _refresh_points() -> void:
	if is_instance_valid(_lash):
		_lash.enabled = integrity.intact()
	var reach_px: float = tuning.reach_tiles * TILE_PX
	var deck := deck_rect()
	for peer: int in _peers:
		var body := body_of(peer)
		var climb := _points[peer * 2] as RescuePoint
		var pull := _points[peer * 2 + 1] as RescuePoint
		var swimming: bool = body != null and rider_state(peer) == Rider.IN_WATER and integrity.intact()
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


# Clients: the host's rider states (riders only, in range), clock and vessel, from a resync or a
# snapshot.
func _apply_state(states: Dictionary, vessel_value: float, time_s: float) -> void:
	for peer: Variant in states:
		var state: Variant = states[peer]
		if peer is int and state is int and _states.has(peer) and state >= 0 and state < Rider.size():
			_states[peer] = state
	elapsed_s = time_s
	if integrity.has_integrity():
		integrity.value = clampf(vessel_value, 0.0, integrity.maximum)
		if integrity.value <= 0.0:
			integrity.broken = true
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
		receive_state.rpc_id(peer, _states.duplicate(), integrity.value, elapsed_s)


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
		body.pinned = false
	for peer: int in _connected_recipients():
		receive_result.rpc_id(peer, result.to_dict())
	ended.emit(result)


func _deck_cells() -> Rect2i:
	var top_left := Vector2i((deck_rect().position / TILE_PX).floor())
	return Rect2i(top_left, DECK_TILES)


func _deck_spot(index: int) -> Vector2:
	return deck_center() + Vector2((index - 1.5) * SPACING_PX, 0.0)
