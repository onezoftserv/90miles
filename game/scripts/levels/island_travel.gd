class_name IslandTravel
extends Node
## The run's island keeper (escape-routes "Split parties", crossing "Arrival"): a child of the
## session that holds the island the session is on and moves the whole party to the next one. A
## session runs one live level, so a rider whose crossing ended waits out of play (held, hidden,
## meters frozen) until nobody living is left on the island and no crossing is running; then the
## host asks every peer, in one reliable call, to free the old island and what it put in the
## session, build the next one from its layout, land every player on the cell the host picked for
## them (ArrivalScatter: the landing cells, or a scattered beach cell for a wider route such as the
## board's) with the health and energy they had, beach an intact raft and place the pick-ups. A client never loads an
## island on its own: it only follows the host's call (and, joining late, the host's world state).
## Exactly 1 player never waits: their crossing ending is the whole condition.

## What the party's state asks for.
enum Outcome {
	## Someone living is still on the island, or in a crossing.
	PLAYING,
	## Nobody is left playing here, riders wait, and the island names a next one.
	TRAVEL,
	## Nobody is left playing here and there is nowhere to go: the run is over.
	OVER,
}

## Every peer: the next island is built, furnished and the players are on it.
signal island_loaded(loaded: SandbarIsland)

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
## The session's own nodes, which stay when an island's furniture goes.
const SESSION_NODES: Array[StringName] = [
	&"Players", &"PlayerSpawner", &"Entities", &"EntitySpawner", &"Pickups", &"PickupSpawner",
]
const RAFT_NAME: StringName = &"Raft"
## escape-routes "Split parties" (dropped-teammate-state): once dropped players still on the island
## are all that keep waiting riders from landing, each one's time left is cut to at most this.
const DROPPED_HOLD_S: float = 30.0

## The island the session is on (it sits beside the session, in the same parent).
var island: SandbarIsland
var session: CoopSession
## How many islands the party has stood on this run, the sandbar being 1 (run summary totals).
var islands_reached: int = 1

# The results of the crossings that ended since the island loaded.
var _results: Array[CrossingResult] = []
# Peers a joiner or rejoined player is told are waiting; held as their bodies appear.
var _waiting_peers: Array[int] = []
var _travel_queued: bool = false


## Starts keeping `current` for `for_session`. Call once the session is in the tree.
func setup(for_session: CoopSession, current: SandbarIsland) -> void:
	session = for_session
	island = current
	session.island_travel_requested.connect(_load)
	session.player_spawned.connect(_on_player_spawned)
	session.player_rebound.connect(_on_player_rebound)
	session.removal_recorded.connect(_on_removal_recorded)
	session.player_disconnected.connect(_on_player_disconnected)
	session.world_state_received.connect(follow)
	session.join_extras = _join_extras
	for peer_id: int in session.peer_ids():
		_watch(session.body(peer_id))


## A crossing ended with `result` (every peer, from Crossing.ended): its riders wait out of play.
## The host moves the party on when nobody else is left playing.
func crossing_ended(result: CrossingResult) -> void:
	_results.append(result)
	for peer_id: int in result.riders:
		var rider := session.body(peer_id)
		if rider != null:
			IslandArrival.hold(rider)
	_on_changed()


## What the party's state asks for now. On the host a TRAVEL answer also starts the travel (after
## this frame, never from inside the signal that asked). A dropped player still on the island (not
## waiting, not in a crossing) keeps it open until removed; once such players are all that keep
## riders waiting, the host cuts each one's time to DROPPED_HOLD_S. A drop never ends the run early.
func check() -> Outcome:
	var waiting: int = 0
	var dropped_here: Array[int] = []
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		if player.meters.dead:
			continue
		if player.left_island:
			waiting += 1
		elif session.is_dropped(peer_id) and not session.has_left(peer_id):
			dropped_here.append(peer_id)
		else:
			return Outcome.PLAYING
	if not dropped_here.is_empty():
		if waiting > 0:
			for peer_id: int in dropped_here:
				session.shorten_drop(peer_id, DROPPED_HOLD_S)
		return Outcome.PLAYING
	if waiting == 0 or island.layout.next_island.is_empty():
		return Outcome.OVER
	if session.multiplayer.is_server() and not _travel_queued:
		_travel_queued = true
		_travel_when_idle.call_deferred()
	return Outcome.TRAVEL


## Host: loads island `next_id` for everyone, landing every player in the session on the cell
## the host picks for them on the next island's layout (crossing "Arrival scatter").
func travel(next_id: StringName) -> void:
	if not session.multiplayer.is_server():
		return
	var cells: Dictionary[int, Vector2i] = {}
	var next_layout := GameState.content.get_entry(&"islands", next_id) as IslandLayoutData
	if next_layout != null:
		cells = ArrivalScatter.pick(IslandLayout.build(next_layout), _scatter_by_peer(), _landing_seed())
	var arrivals: Dictionary = {}
	for peer_id: int in session.peer_ids():
		var meters := session.body(peer_id).meters
		var arrival: Dictionary = {"health": meters.health, "energy": meters.energy}
		if cells.has(peer_id):
			arrival["cell"] = cells[peer_id]
		arrivals[peer_id] = arrival
	session.travel_to.rpc(String(next_id), arrivals, _beached_integrity())


## Client: a joiner or rejoined player hears which island the host is on and who waits there. It
## builds the same island, beaches the raft the host has and holds the waiting riders.
func follow(state: Dictionary) -> void:
	if session.multiplayer.is_server():
		return
	var id: Variant = state.get("island")
	if id is StringName and not (id as StringName).is_empty() and id != island.layout.id:
		var raft: Variant = state.get("raft")
		_load(id, {}, raft if raft is float else 0.0)
	var islands: Variant = state.get("islands")
	if islands is int and islands >= 1:
		islands_reached = islands
	var waiting: Variant = state.get("waiting")
	_waiting_peers.clear()
	if waiting is Array:
		for peer_id: Variant in waiting:
			if peer_id is int:
				_waiting_peers.append(peer_id)
	_hold_waiting()


# What a joiner is told beyond the sky: the island, the riders waiting and the raft lying there.
func _join_extras() -> Dictionary:
	var waiting: Array[int] = []
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		if player.left_island and not player.meters.dead:
			waiting.append(peer_id)
	var raft := session.get_node_or_null(NodePath(RAFT_NAME))
	var integrity: float = 0.0
	if raft != null and raft.get(&"integrity") is float:
		integrity = raft.get(&"integrity")
	return {"island": island.layout.id, "waiting": waiting, "raft": integrity, "islands": islands_reached}


# The sturdiest raft that ended a crossing intact lies on the next island's build site; any other
# vessel is lost (crossing "Beaching by vessel"): only a route whose vessel is a raft kept on
# arrival beaches one, never a board, a car or swimmers.
func _beached_integrity() -> float:
	var best: float = 0.0
	for result: CrossingResult in _results:
		var route := GameState.content.get_entry(&"routes", result.route_id) as RouteData
		if route == null or route.vessel != DataEnums.Vessel.RAFT or not route.vessel_kept_on_arrival:
			continue
		if not result.broken and result.integrity > best:
			best = result.integrity
	return best


# Every living player's arrival scatter: their crossing's route's, the default for anyone else.
# The dead are left out (they land on the landing cells), so a lone survivor's board is not
# scattered away from a body.
func _scatter_by_peer() -> Dictionary[int, Vector2i]:
	var scatter: Dictionary[int, Vector2i] = {}
	for peer_id: int in session.peer_ids():
		if not session.body(peer_id).meters.dead:
			scatter[peer_id] = ArrivalScatter.DEFAULT_TILES
	for result: CrossingResult in _results:
		var route := GameState.content.get_entry(&"routes", result.route_id) as RouteData
		if route == null:
			continue
		for peer_id: int in result.riders:
			if scatter.has(peer_id):
				scatter[peer_id] = route.arrival_scatter_tiles
	return scatter


# The scatter's roll: the run's seed and how far the party has come, so a run lands the same way.
func _landing_seed() -> int:
	var run_seed: Variant = session.world_state.get("run_seed", 0)
	return hash([run_seed if run_seed is int else 0, islands_reached])


func _on_changed() -> void:
	check()


func _on_removal_recorded(_peer_id: int, _player_name: String) -> void:
	_on_changed()


# Host: a drop may leave a dropped body as all that keeps riders waiting (its hold is cut now).
func _on_player_disconnected(_peer_id: int) -> void:
	_on_changed()


func _on_player_spawned(peer_id: int, spawned: PlayerBody) -> void:
	_watch(spawned)
	if _waiting_peers.has(peer_id):
		IslandArrival.hold(spawned)


# coop-reconnect: a rejoined player's body reaches the joiner under its new peer, after the world
# state that names it as waiting.
func _on_player_rebound(_old_peer: int, new_peer: int, rebound: PlayerBody) -> void:
	if _waiting_peers.has(new_peer):
		IslandArrival.hold(rebound)


func _watch(player: PlayerBody) -> void:
	if player != null and not player.meters.died.is_connected(_on_changed):
		player.meters.died.connect(_on_changed)


func _hold_waiting() -> void:
	for peer_id: int in _waiting_peers:
		var player := session.body(peer_id)
		if player != null:
			IslandArrival.hold(player)


# Deferred from check(): the state may have moved on since. The flag stays up while it runs, so a
# check() here never queues it again: a refused landing waits for the next change instead of
# re-queuing itself within the same deferred flush, forever (dropped-teammate-state D5).
func _travel_when_idle() -> void:
	if is_inside_tree() and check() == Outcome.TRAVEL:
		travel(island.layout.next_island)
	_travel_queued = false


# Every peer, from the host's travel_to: the old level goes, the next one is built and the players
# land on it.
func _load(layout_id: StringName, arrivals: Dictionary, raft_integrity: float) -> void:
	var next_layout := GameState.content.get_entry(&"islands", layout_id) as IslandLayoutData
	if next_layout == null:
		return
	var with_creatures: bool = island.with_creatures
	_clear_level()
	var fresh := ISLAND_SCENE.instantiate() as SandbarIsland
	fresh.layout = next_layout
	fresh.with_creatures = with_creatures
	session.get_parent().add_child(fresh)
	island = fresh
	session.terrain = fresh.terrain
	session.spawn_points = fresh.spawn_points(false)
	_land(arrivals)
	fresh.furnish(session)
	fresh.beach_raft(raft_integrity)
	if session.multiplayer.is_server():
		fresh.place_pickups(session)
	_results.clear()
	# An off-graph layout (the secret cay) is never an island reached (endings-progression).
	if not next_layout.off_graph:
		islands_reached += 1
	island_loaded.emit(fresh)


# Frees the old island and everything it put in the session (its workbench, routes, build site,
# raft, spots, signs and creature spawner). The host also frees the pick-ups and creatures: the
# spawners take them off every client.
func _clear_level() -> void:
	island.get_parent().remove_child(island)
	island.queue_free()
	for child: Node in session.get_children():
		if child == self or SESSION_NODES.has(child.name):
			continue
		session.remove_child(child)
		child.queue_free()
	if session.multiplayer.is_server():
		for node: Node in session.pickups.get_children():
			node.queue_free()
		for node: Node in session.entities.get_children():
			node.queue_free()


# Everyone's ground and camera, then the arrivals on the cells the host sent (a cell that is not
# land on this island falls back to the landing cells in peer order), with the health and energy
# the host sent (the host's own meters already have them).
func _land(arrivals: Dictionary) -> void:
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		player.terrain = island.terrain
		IslandArrival.fit_camera(player, island.bounds)
	var peers: Array[int] = []
	for peer_id: Variant in arrivals:
		peers.append(peer_id)
	var positions: Dictionary[int, Vector2] = IslandArrival.landing_positions(island.built, peers)
	var is_host: bool = session.multiplayer.is_server()
	for peer_id: int in peers:
		var player := session.body(peer_id)
		if player == null:
			continue
		var at: Vector2 = positions[peer_id]
		var cell: Variant = (arrivals[peer_id] as Dictionary).get("cell")
		if cell is Vector2i and _is_land(cell):
			at = IslandLayout.cell_center(cell)
		IslandArrival.land(player, at, island.terrain)
		if is_host and not player.meters.dead:
			player.meters.health = arrivals[peer_id]["health"]
			player.meters.energy = arrivals[peer_id]["energy"]


# A cell of the island a player can stand on: walkable ground, not water.
func _is_land(cell: Vector2i) -> bool:
	var ground: Variant = island.built.terrain.cells.get(cell)
	return ground != null and IslandLayout.WALKABLE.has(ground) and ground != DataEnums.Terrain.SHALLOWS
