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
## Every peer (guardacostas-capture "Release at the next island"): the party was released from an
## island that names no next one, so every player has left it and the run is over, as leaving it by a
## route is. The shell shows the run summary.
signal left_the_chain

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
## The session's own nodes, which stay when an island's furniture goes. The world event bus is the
## session's (guardacostas-stealth decision 8), so it stays too: the next island's spawner and patrol
## boats listen to it.
const SESSION_NODES: Array[StringName] = [
	&"Players", &"PlayerSpawner", &"Entities", &"EntitySpawner", &"Pickups", &"PickupSpawner",
	&"WorldEvents", &"CaptureScene",
]
const RAFT_NAME: StringName = &"Raft"
## escape-routes "Split parties" (dropped-teammate-state): once dropped players still on the island
## are all that keep waiting riders from landing, each one's time left is cut to at most this.
const DROPPED_HOLD_S: float = 30.0

## The island the session is on (it sits beside the session, in the same parent).
var island: SandbarIsland
var session: CoopSession
## How many islands the party has stood on this run, the sandbar being 1 (run summary totals): the
## highest index in the history (guardacostas-capture "Island history"), so a restart or a second
## arrival never counts an island twice. A joiner takes the host's number.
var islands_reached: int = 1
## The run's islands in order, with their index (guardacostas-capture design.md §8). Every peer
## appends from the host's travel message, which carries the index; only the host asks previous().
var history: IslandHistory = IslandHistory.new()

# The results of the crossings that ended since the island loaded.
var _results: Array[CrossingResult] = []
# Peers a joiner or rejoined player is told are waiting; held as their bodies appear.
var _waiting_peers: Array[int] = []
var _travel_queued: bool = false
## Tests only (island-generator "A mismatched client takes the host's island"): chain templates this
## peer uses in place of the catalog's, by id.
var chain_overrides: Dictionary[StringName, ChainData] = {}
# Client: the travel waiting for the host's text of an island whose hash differs from the host's:
# {island_id, arrivals, raft, index, island_hash}; empty when none.
var _pending: Dictionary = {}
# Client: islands built from the host's text, by island hash.
var _received: Dictionary[String, IslandLayoutData] = {}


## The island keeper of `of_session` (its IslandTravel child, whatever its name), or null.
static func of(of_session: CoopSession) -> IslandTravel:
	if of_session == null:
		return null
	for child: Node in of_session.get_children():
		if child is IslandTravel:
			return child as IslandTravel
	return null


## Starts keeping `current` for `for_session`. Call once the session is in the tree.
func setup(for_session: CoopSession, current: SandbarIsland) -> void:
	session = for_session
	island = current
	if history.entries.is_empty() and island.layout != null:
		history.arrive(IslandSource.source_id(island.layout), 1, island.layout.off_graph)
	session.island_travel_requested.connect(_load)
	session.island_text_requested.connect(_on_island_text_requested)
	session.island_text_received.connect(_on_island_text_received)
	session.off_the_chain_requested.connect(end_off_the_chain)
	session.party_travel_requested.connect(_on_party_travel)
	session.capture_state_changed.connect(_on_changed)
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
	# guardacostas-capture "Whole-party capture": checked before the island loads or the run ends. A
	# taken captive is held like a rider, so it counts as gone below.
	var keeper := CaptureScene.of(session)
	if keeper != null and keeper.holds_travel():
		return Outcome.PLAYING
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
	var index: int = _next_index(next_id)
	var resolved: Dictionary = resolve(next_id, index)
	var next_layout: IslandLayoutData = resolved.get("layout")
	if next_layout != null:
		cells = ArrivalScatter.pick(IslandLayout.build(next_layout), _scatter_by_peer(), _landing_seed(next_id), _dead_peers())
	var arrivals: Dictionary = {}
	for peer_id: int in session.peer_ids():
		var meters := session.body(peer_id).meters
		var arrival: Dictionary = {"health": meters.health, "energy": meters.energy}
		if cells.has(peer_id):
			arrival["cell"] = cells[peer_id]
		arrivals[peer_id] = arrival
	session.travel_to.rpc(String(next_id), index, resolved.get("island_hash", ""), arrivals, _beached_integrity())


## The island `island_id` names as island number `index` of this run (island-generator design §6):
## a handmade layout, or the chain's island generated from the run seed. See IslandSource.resolve.
func resolve(island_id: StringName, index: int) -> Dictionary:
	return IslandSource.resolve(island_id, index, run_seed(), null, chain_overrides)


## The run's seed, from the world state the host keeps and every joiner receives (0 when unset).
func run_seed() -> int:
	var value: Variant = session.world_state.get("run_seed", 0)
	return value if value is int else 0


# The index an island reached by a route or a release gets: an off-graph layout keeps the current
# one, anything else (a chain included) is one more.
func _next_index(island_id: StringName) -> int:
	var handmade := GameState.content.get_entry(&"islands", island_id) as IslandLayoutData
	return history.next_index(handmade != null and handmade.off_graph)


## Host: the previous island (guardacostas-capture "Island history"): the last on-graph island before
## this one with a lower index; on island 1, island 1 itself; never the secret cay.
func previous() -> StringName:
	return history.previous()


## Host (guardacostas-capture "Previous island after capture"): the party restarts the previous
## island, rebuilt from its layout and the run seed, every player landing on its landing cells
## (within 5 tiles) with the health and energy they have, and nothing beached.
func restart() -> void:
	if not session.multiplayer.is_server():
		return
	_relocate(previous(), history.previous_index())


## Host (guardacostas-capture "Release at the next island"): the party lands on the next island this
## one names, as a restart does, and it counts as reached. When this island names none, the run ends
## as leaving it does (every peer: `end_off_the_chain`).
func release() -> void:
	if not session.multiplayer.is_server():
		return
	var next_id: StringName = island.layout.next_island
	if next_id.is_empty() or resolve(next_id, _next_index(next_id)).is_empty():
		session.end_off_the_chain.rpc()
		return
	_relocate(next_id, _next_index(next_id))


## Every peer, from the host (CoopSession.end_off_the_chain): the party was released from an island
## that names no next one. Every living player is held out of play as a rider on the next shore
## would be, so the run is OVER, and the shell shows the summary.
func end_off_the_chain() -> void:
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		if player != null and not player.meters.dead:
			IslandArrival.hold(player)
	left_the_chain.emit()


# Host: a TRAVEL_NEXT_ISLAND or TRAVEL_PREVIOUS_ISLAND effect.
func _on_party_travel(onward: bool) -> void:
	if onward:
		release()
	else:
		restart()


# Host: every player in the session lands on `island_id` at its landing cells in peer order (no
# scatter), with their health and energy, as island number `index`, with no vessel beached. A chain
# is regenerated from the run seed, so the same reference gives the same island.
func _relocate(island_id: StringName, index: int) -> void:
	var arrivals: Dictionary = {}
	for peer_id: int in session.peer_ids():
		var meters := session.body(peer_id).meters
		arrivals[peer_id] = {"health": meters.health, "energy": meters.energy}
	var resolved: Dictionary = resolve(island_id, index)
	session.travel_to.rpc(String(island_id), index, resolved.get("island_hash", ""), arrivals, 0.0)


## Client: a joiner or rejoined player hears which island the host is on and who waits there. It
## builds the same island, beaches the raft the host has and holds the waiting riders.
func follow(state: Dictionary) -> void:
	if session.multiplayer.is_server():
		return
	var id: Variant = state.get("island")
	var index: Variant = state.get("island_index", history.current_index())
	var island_hash: Variant = state.get("island_hash", &"")
	if not index is int:
		index = history.current_index()
	if id is StringName and not (id as StringName).is_empty() and (id != history.current_id() or index != history.current_index()):
		var raft: Variant = state.get("raft")
		var wanted: String = String(island_hash) if island_hash is StringName else ""
		if CoopSession.is_travel(id, index, wanted):
			_load(id, {}, raft if raft is float else 0.0, index, wanted)
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
	return {
		"island": history.current_id(), "island_index": history.current_index(),
		"island_hash": StringName(IslandSource.hash_of(island.layout)), "waiting": waiting, "raft": integrity,
		"islands": islands_reached,
	}


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


# Every player's arrival scatter: their crossing's route's, the default for anyone else.
func _scatter_by_peer() -> Dictionary[int, Vector2i]:
	var scatter: Dictionary[int, Vector2i] = {}
	for peer_id: int in session.peer_ids():
		scatter[peer_id] = ArrivalScatter.DEFAULT_TILES
	for result: CrossingResult in _results:
		var route := GameState.content.get_entry(&"routes", result.route_id) as RouteData
		if route == null:
			continue
		for peer_id: int in result.riders:
			if scatter.has(peer_id):
				scatter[peer_id] = route.arrival_scatter_tiles
	return scatter


# The dead keep their landing cell but anchor nobody's scatter, so a lone survivor's board is not
# scattered away from a body.
func _dead_peers() -> Array[int]:
	var dead: Array[int] = []
	for peer_id: int in session.peer_ids():
		if session.body(peer_id).meters.dead:
			dead.append(peer_id)
	return dead


# The scatter's roll: the run's seed, how far the party has come and the island it lands on (an
# off-graph island such as the secret cay does not count as reached), so a run lands the same way.
func _landing_seed(next_id: StringName) -> int:
	var run_seed: Variant = session.world_state.get("run_seed", 0)
	return hash([run_seed if run_seed is int else 0, islands_reached, String(next_id)])


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
# land on it. A chain's island is generated here from the run seed; when its hash is not the host's
# `island_hash`, the client warns, asks the host for its text once and lands when it arrives
# (island-generator design §6).
func _load(layout_id: StringName, arrivals: Dictionary, raft_integrity: float, index: int = 0, island_hash: String = "") -> void:
	if index <= 0:
		index = _next_index(layout_id)
	var resolved: Dictionary = resolve(layout_id, index)
	var next_layout: IslandLayoutData = resolved.get("layout")
	if next_layout == null:
		return
	if resolved["chain"] and resolved["island_hash"] != island_hash:
		next_layout = _received.get(island_hash)
		if next_layout == null:
			_ask_for(layout_id, arrivals, raft_integrity, index, island_hash, String(resolved["island_hash"]))
			return
	_pending.clear()
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
	# The host's message names the island's index (0 from an older caller: the next index). An
	# off-graph layout (the secret cay) is never an island reached (endings-progression), and the
	# islands reached are the highest index, so a restart counts nothing twice.
	history.arrive(layout_id, index, next_layout.off_graph)
	islands_reached = maxi(islands_reached, history.reached())
	island_loaded.emit(fresh)


# Client: the island built here differs from the host's; warn, keep the travel and ask once.
func _ask_for(island_id: StringName, arrivals: Dictionary, raft: float, index: int, island_hash: String, ours: String) -> void:
	if session.multiplayer.is_server():
		push_error("island-generator: the host's own %s %d does not match its hash" % [island_id, index])
		return
	var asked: bool = not _pending.is_empty() and _pending["island_hash"] == island_hash
	_pending = {"island_id": island_id, "arrivals": arrivals, "raft": raft, "index": index, "island_hash": island_hash}
	if asked:
		return
	push_warning("island-generator: %s %d built here as %s, the host's is %s; asking the host for it" % [island_id, index, ours, island_hash])
	session.request_island.rpc_id(CoopSession.HOST_ID, String(island_id), index)


# Host: a client asked for the text of `island_id` number `index`; it gets the host's island.
func _on_island_text_requested(peer_id: int, island_id: StringName, index: int) -> void:
	var resolved: Dictionary = resolve(island_id, index)
	if resolved.get("chain", false):
		session.receive_island.rpc_id(peer_id, IslandLayoutWriter.write(resolved["layout"]))


# Client: the host's text. It parses with its size limit, must hash to the host's hash, and then the
# waiting travel lands on it.
func _on_island_text_received(text: String) -> void:
	if _pending.is_empty():
		return
	var island_hash: String = _pending["island_hash"]
	if text.sha256_text() != island_hash:
		push_warning("island-generator: the host's island text does not match its hash; ignored")
		return
	var layout := IslandLayoutWriter.parse(text, GameState.content)
	if layout == null:
		push_warning("island-generator: the host's island text does not read; ignored")
		return
	layout.set_meta(IslandSource.ART_KEY_META, StringName(island_hash))
	_received[island_hash] = layout
	var waiting: Dictionary = _pending
	_load(waiting["island_id"], waiting["arrivals"], waiting["raft"], waiting["index"], island_hash)


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
