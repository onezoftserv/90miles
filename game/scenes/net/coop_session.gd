class_name CoopSession
extends Node2D
## A co-op session on one island (coop-networking): the players and their spawner, the
## entities and theirs, and the RPCs between host and clients. It uses only the multiplayer
## API of its own branch (`multiplayer`), never the tree's default one, so tests can run a host
## and clients in one process. A level instances it, sets terrain, spawn_points and
## world_state, then calls start() once the peer is set (NetManager in the game, NetHarness in
## tests). Solo is the same code on the offline peer.
##
## RPC rules (review item 17): clients send intents only to the host (rpc_id(1)); every intent
## handler returns unless it runs on the host; the acting player is the sender's own, never one
## named in the message; host-to-client calls are authority-only and also check the sender.

## A player body entered this session's tree (on every peer).
signal player_spawned(peer_id: int, body: PlayerBody)
## Client: the host's world state arrived.
signal world_state_received(state: Dictionary)

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HOST_ID: int = 1
const MAX_PLAYERS: int = 4
## An intent may claim at most this much time (one slow frame).
const MAX_INTENT_DELTA_S: float = 0.1
## Squared length an intent's direction may reach (1 plus float slack).
const MAX_DIRECTION_LENGTH_SQUARED: float = 1.001
## World-state keys a joiner accepts, with their types; anything else is dropped.
const WORLD_STATE_TYPES: Dictionary[String, int] = {
	"island_seed": TYPE_INT,
	"weather": TYPE_STRING_NAME,
	"time_of_day_s": TYPE_FLOAT,
}

## Where players appear, in join order (the host first). Set by the level.
@export var spawn_points: Array[Vector2] = [Vector2.ZERO]
## Ground and current for every player body. Set by the level.
var terrain: TerrainQuery = TerrainQuery.new()
## Host: what each joiner receives (island seed, weather, time of day). Client: what arrived.
var world_state: Dictionary = {}

var _bodies: Dictionary[int, PlayerBody] = {}
var _joined: int = 0
var _started: bool = false

@onready var players: Node2D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var entities: Node2D = $Entities
@onready var entity_spawner: MultiplayerSpawner = $EntitySpawner


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player


## Starts the session on the branch's current peer. The host (or solo) spawns its own player
## and then one per joining peer; a client receives everything from the host.
func start() -> void:
	if _started:
		return
	_started = true
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		_add_player(multiplayer.get_unique_id())


## The body of `peer_id`'s player in this session, or null.
func body(peer_id: int) -> PlayerBody:
	var found: PlayerBody = _bodies.get(peer_id)
	return found if is_instance_valid(found) else null


## Peer ids with a player in this session, sorted.
func peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _bodies:
		if is_instance_valid(_bodies[id]):
			ids.append(id)
	ids.sort()
	return ids


## Sends an intent of this peer's own player to the host (PlayerNet calls it every frame).
func send_intent(seq: int, intent: MoveIntent, delta: float) -> void:
	submit_intent.rpc_id(HOST_ID, seq, intent.direction, intent.run, intent.crouch, intent.interact_held, delta)


@rpc("any_peer", "call_local", "unreliable_ordered")
func submit_intent(seq: int, direction: Vector2, run: bool, crouch: bool, interact: bool, delta: float) -> void:
	if not multiplayer.is_server():
		return
	var target := body(multiplayer.get_remote_sender_id())
	if target == null or not is_valid_intent(direction, delta):
		return
	target.net.enqueue(seq, MoveIntent.create(direction, run, crouch, interact), delta)


@rpc("authority", "call_remote", "reliable")
func receive_world_state(state: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	world_state = checked_world_state(state)
	world_state_received.emit(world_state)


## Whether an intent's payload is in range (finite, direction length ≤ 1, a sane time step).
static func is_valid_intent(direction: Vector2, delta: float) -> bool:
	return direction.is_finite() and direction.length_squared() <= MAX_DIRECTION_LENGTH_SQUARED \
		and is_finite(delta) and delta > 0.0 and delta <= MAX_INTENT_DELTA_S


## The known world-state keys of `state`, with their types enforced.
static func checked_world_state(state: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for key: String in WORLD_STATE_TYPES:
		if not state.has(key):
			continue
		var value: Variant = state[key]
		match WORLD_STATE_TYPES[key]:
			TYPE_INT:
				if value is int:
					clean[key] = value
			TYPE_FLOAT:
				if value is float or value is int:
					clean[key] = float(value)
			TYPE_STRING_NAME:
				if value is StringName or value is String:
					clean[key] = StringName(value)
	return clean


func _on_peer_connected(peer_id: int) -> void:
	_add_player(peer_id)
	if body(peer_id) != null:
		receive_world_state.rpc_id(peer_id, world_state)


func _add_player(peer_id: int) -> void:
	if _bodies.has(peer_id):
		return
	if _bodies.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	var spot: Vector2 = Vector2.ZERO
	if not spawn_points.is_empty():
		spot = spawn_points[_joined % spawn_points.size()]
	_joined += 1
	player_spawner.spawn({"peer": peer_id, "position": spot})


# Runs on every peer: on the host through spawn(), on clients when the host's spawn arrives.
func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data if data is Dictionary else {}
	var peer_id: int = info.get("peer", 0) if info.get("peer", 0) is int else 0
	var spot: Vector2 = info.get("position") if info.get("position") is Vector2 else Vector2.ZERO
	var new_body := PLAYER_SCENE.instantiate() as PlayerBody
	new_body.name = str(peer_id)
	new_body.position = spot
	new_body.terrain = terrain
	var role := PlayerNet.role_for(multiplayer.is_server(), multiplayer.get_unique_id(), peer_id)
	(new_body.get_node(^"PlayerNet") as PlayerNet).attach(peer_id, role, send_intent)
	_bodies[peer_id] = new_body
	new_body.tree_exiting.connect(_on_body_exiting.bind(peer_id, new_body))
	new_body.ready.connect(_on_body_ready.bind(peer_id, new_body), CONNECT_ONE_SHOT)
	return new_body


func _on_body_ready(peer_id: int, spawned: PlayerBody) -> void:
	player_spawned.emit(peer_id, spawned)


func _on_body_exiting(peer_id: int, leaving: PlayerBody) -> void:
	if _bodies.get(peer_id) == leaving:
		_bodies.erase(peer_id)
