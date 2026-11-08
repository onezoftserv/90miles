class_name IslandRoutes
extends Node
## The routes an island offers (escape-routes). The level adds one at the path `Routes` of the
## session on every peer. The host starts a route for a sender, picks the riders and tells the
## clients; the riders leave the island into the crossing and everyone else stays, with every route
## still on offer. Discovery is host-only state; no map UI reads it yet.

## Every peer: `route_id` started with these riders.
signal route_started(route_id: StringName, peer_ids: Array[int])
## Host: a route became known.
signal route_discovered(route_id: StringName)
## A joiner: the host's departures and crossings under way arrived (crossing-late-join);
## `restored` are the crossings this peer built or refreshed from them.
signal progress_received(restored: Array[Crossing])

const GROUP: StringName = &"island_routes"
const HOST_ID: int = 1

var offered: Array[RouteData] = []
var discovered: Dictionary[StringName, bool] = {}
## Peer id -> the route that player left by.
var departed: Dictionary[int, StringName] = {}
## Host: route id -> integrity of the vessel that left (the sandbar frees the raft as the route starts).
var departure_integrity: Dictionary[StringName, float] = {}

var _session: CoopSession


func _ready() -> void:
	add_to_group(GROUP)


## Offers `route_ids` in `session`'s world.
func setup(session: CoopSession, route_ids: Array[StringName]) -> void:
	_session = session
	for id: StringName in route_ids:
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		if route != null:
			offered.append(route)
			discovered[id] = route.starts_discovered
	WeatherManager.weather_changed.connect(_on_weather_changed)
	session.player_spawned.connect(_on_player_spawned)
	session.player_rebound.connect(_on_player_rebound)


func _exit_tree() -> void:
	if WeatherManager.weather_changed.is_connected(_on_weather_changed):
		WeatherManager.weather_changed.disconnect(_on_weather_changed)


func is_discovered(route_id: StringName) -> bool:
	return discovered.get(route_id, false)


## The peer of `player` in this island's session, or 0 (coop-reconnect: never the node name,
## which a reclaimed body keeps from its first peer).
func peer_of(player: PlayerBody) -> int:
	return _session.peer_of(player) if is_instance_valid(_session) else 0


func has_left(peer_id: int) -> bool:
	return departed.has(peer_id)


## The route `peer_id`'s player left by, or empty.
func route_left_by(peer_id: int) -> StringName:
	return departed.get(peer_id, &"")


## Host: starts `route_id` for `peer`'s player. False, changing nothing, when the route is not
## offered or not discovered, the player is not on the island, out of reach of the starter, or the
## requirements or rider rules refuse.
func start_for(peer: int, route_id: StringName) -> bool:
	if not is_instance_valid(_session) or not _session.multiplayer.is_server():
		return false
	discover_check()
	var route := _route(route_id)
	var sender := _session.body(peer)
	if route == null or sender == null or has_left(peer) or not is_discovered(route_id):
		return false
	var anchor: Variant = _anchor(route, sender)
	if anchor == null or not RouteLauncher.can_start(route, sender):
		return false
	var riders := RouteLauncher.riders(route, sender, _on_island(), anchor)
	if riders.is_empty():
		return false
	var peers: Array[int] = []
	for rider: PlayerBody in riders:
		peers.append(peer_of(rider))
	departure_integrity[route_id] = _structure_integrity(route)
	# Clients hear first: their crossing must exist before the host's plan reaches it.
	if not _session.multiplayer.get_peers().is_empty():
		receive_departure.rpc(route_id, peers)
	_depart(route_id, peers)
	return true


## Host: marks every undiscovered route whose discover conditions hold for a player on the island.
func discover_check() -> void:
	for route: RouteData in offered:
		if is_discovered(route.id) or route.discover_conditions.is_empty():
			continue
		for player: PlayerBody in _on_island():
			if ConditionCheck.all_hold(route.discover_conditions, player):
				discovered[route.id] = true
				route_discovered.emit(route.id)
				break


## Clients: the host started a route; its riders leave here too.
@rpc("authority", "call_remote", "reliable")
func receive_departure(route_id: StringName, peer_ids: Array[int]) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or _route(route_id) == null:
		return
	_depart(route_id, peer_ids)


## Host: tells `peer`, which just joined or took back its body, who left by which route, the next
## crossing number and every crossing under way, and sends it those crossings' messages from then on
## (crossing-late-join). CoopSession calls it after the join reply, so the joiner already holds
## every body under its current peer.
func send_progress(peer: int) -> void:
	if not is_instance_valid(_session) or not _session.multiplayer.is_server() or not _session.multiplayer.get_peers().has(peer):
		return
	var crossings := Crossing.under_way(_session)
	var snapshots: Array = []
	for crossing: Crossing in crossings:
		snapshots.append(CrossingSnapshot.of(crossing).to_dict())
	var departures: Dictionary = {}
	for rider: int in departed:
		departures[rider] = String(departed[rider])
	receive_progress.rpc_id(peer, departures, Crossing.next_serial(_session), snapshots)
	for crossing: Crossing in crossings:
		crossing.share_with(peer)


## A joiner: the host's departures replace this peer's (nothing starts: those players already left),
## the crossing counter follows the host's, and each crossing under way is built or refreshed.
@rpc("authority", "call_remote", "reliable")
func receive_progress(departures: Dictionary, host_next_serial: int, snapshots: Array) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or not is_instance_valid(_session):
		return
	_apply_departures(departures)
	if host_next_serial >= 0 and host_next_serial <= Crossing.MAX_SERIAL + 1:
		Crossing.follow_serial(_session, host_next_serial)
	var restored: Array[Crossing] = []
	for raw: Variant in snapshots.slice(0, NetPeers.MAX_PLAYERS):
		var crossing := Crossing.restore(_session, CrossingSnapshot.from_dict(raw))
		if crossing != null:
			restored.append(crossing)
	progress_received.emit(restored)


# Only peer ids leaving by a route this island offers are kept.
func _apply_departures(departures: Dictionary) -> void:
	var kept: Dictionary[int, StringName] = {}
	for rider: Variant in departures:
		var route_id: Variant = departures[rider]
		if rider is int and (route_id is String or route_id is StringName) and _route(StringName(route_id)) != null:
			kept[rider] = StringName(route_id)
	departed = kept


func _depart(route_id: StringName, peer_ids: Array[int]) -> void:
	for peer: int in peer_ids:
		departed[peer] = route_id
	route_started.emit(route_id, peer_ids)


func _route(route_id: StringName) -> RouteData:
	for route: RouteData in offered:
		if route.id == route_id:
			return route
	return null


# Where riders must stand: the built structure of a BUILD_SITE route (the sender must be in
# reach of it), the sender's own spot otherwise. Null when the structure is missing or too far.
func _anchor(route: RouteData, sender: PlayerBody) -> Variant:
	if route.starter_kind != RouteData.StarterKind.BUILD_SITE:
		return sender.global_position
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.STRUCTURE_GROUP):
		var structure := node as Node2D
		if structure != null and structure.get_meta(&"recipe_id", &"") == route.starter_id:
			var reach_px: float = InteractionPicker.REACH_PX + PlayerBody.REACH_SLACK_PX
			return structure.global_position if sender.global_position.distance_to(structure.global_position) <= reach_px else null
	return null


# The integrity of the built structure a BUILD_SITE route starts from; the route's own otherwise.
func _structure_integrity(route: RouteData) -> float:
	if route.starter_kind == RouteData.StarterKind.BUILD_SITE:
		for node: Node in get_tree().get_nodes_in_group(PlayerBody.STRUCTURE_GROUP):
			if node.get_meta(&"recipe_id", &"") == route.starter_id and node.get(&"integrity") is float:
				return node.get(&"integrity")
	return float(route.vessel_integrity)


func _on_island() -> Array[PlayerBody]:
	var list: Array[PlayerBody] = []
	if not is_instance_valid(_session):
		return list
	for peer: int in _session.peer_ids():
		if not has_left(peer):
			list.append(_session.body(peer))
	return list


func _on_weather_changed(_weather_id: StringName) -> void:
	if is_instance_valid(_session) and _session.multiplayer.is_server():
		discover_check()


func _on_player_spawned(_peer_id: int, _body: PlayerBody) -> void:
	if is_instance_valid(_session) and _session.multiplayer.is_server():
		discover_check.call_deferred()


# coop-reconnect: a player who left by a route and rejoined is still gone, under the new peer.
func _on_player_rebound(old_peer: int, new_peer: int, _body: PlayerBody) -> void:
	if departed.has(old_peer):
		departed[new_peer] = departed[old_peer]
		departed.erase(old_peer)
