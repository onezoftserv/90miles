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
## Host: a client dropped; its player is now downed for DISCONNECT_DOWNED_S.
signal player_disconnected(peer_id: int)
## Host: a dropped player was removed. Its inventory is dropped at `last_position` (session
## coordinates) once players carry inventories (crafting-inventory).
signal player_removed(peer_id: int, last_position: Vector2)
## Client: the host went away; the session has ended and its players are gone.
signal host_lost
## A quick-chat phrase is shown over `peer_id`'s player (on every peer).
signal quick_chat_shown(peer_id: int, slot: int)
## The solo pause started or ended.
signal paused_changed(paused: bool)
## The roster changed (a name arrived or a lobby player left).
signal roster_updated
## Client: the host answered the join request; `in_run` says whether its run has started.
signal lobby_received(in_run: bool)
## The host started the run (on every peer).
signal run_started

## LOBBY gathers names and spawns nobody; RUN spawns every player (and every joiner at once).
enum Phase {
	LOBBY,
	RUN,
}

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SPEECH_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/speech_bubble.tscn")
const BUBBLE_NAME: StringName = &"SpeechBubble"
const HOST_ID: int = 1
## Connected players at most (dropped players waiting to be removed do not count).
const MAX_PLAYERS: int = NetPeers.MAX_PLAYERS
## A dropped client's player stays downed this long before it is removed.
const DISCONNECT_DOWNED_S: float = 90.0
## An intent may claim at most this much time (one slow frame).
const MAX_INTENT_DELTA_S: float = 0.1
## Squared length an intent's direction may reach (1 plus float slack).
const MAX_DIRECTION_LENGTH_SQUARED: float = 1.001
## World-state keys a joiner accepts, with their types; anything else is dropped. The sky keys
## are WorldSky.to_state().
const WORLD_STATE_TYPES: Dictionary[String, int] = {
	"island_seed": TYPE_INT,
	"weather": TYPE_STRING_NAME,
	"time_of_day_s": TYPE_FLOAT,
	"day": TYPE_INT,
	"weather_left_s": TYPE_FLOAT,
	"pending": TYPE_STRING_NAME,
	"pending_in_s": TYPE_FLOAT,
}

## Where players appear, in join order (the host first). Set by the level.
@export var spawn_points: Array[Vector2] = [Vector2.ZERO]
## Ground and current for every player body. Set by the level.
var terrain: TerrainQuery = TerrainQuery.new()
## Clock and weather every player's meters read. Set by the level (the sky's climate).
var climate: ClimateState = ClimateState.new()
## The clock and weather (weather-daynight). The host owns it and sends it to clients; a client
## follows it and never rolls. Set by the level (WeatherManager.sky in the game); without one the
## session sends no clock.
var sky: WorldSky = null
## Host: what each joiner receives (island seed, weather, time of day). Client: what arrived.
var world_state: Dictionary = {}
## Player names by peer id (ui-shell). The host sets its own; the lobby fills in the others.
var roster: Dictionary[int, String] = {}
## The name this peer plays under (the host's goes into the roster at start(); a client sends
## it in its join request). Set by the shell from the settings.
var local_name: String = GameSettings.DEFAULT_NAME
var phase: Phase = Phase.RUN
## Host time in seconds for the rate limits. Tests replace it.
var clock: Callable
## The quick-chat phrases (the quick-chat content file unless a level or test sets others).
var phrases: QuickChatPhrases
## Language of bubble text; Spanish first until a settings screen exists.
var locale: String = "es"

var _bodies: Dictionary[int, PlayerBody] = {}
## Host: each peer's rate limits.
var _limits: Dictionary[int, PeerLimits] = {}
## Host: seconds left before each dropped client's player is removed.
var _dropped: Dictionary[int, float] = {}
var _joined: int = 0
## Host: seconds until the next periodic clock message.
var _resync_left_s: float = 0.0
var _started: bool = false

@onready var players: Node2D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var entities: Node2D = $Entities
@onready var entity_spawner: MultiplayerSpawner = $EntitySpawner


func _init() -> void:
	clock = _ticks_s


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	if phrases == null:
		phrases = QuickChatPhrases.from_catalog(GameState.content)


## Starts the session on the branch's current peer. The host (or solo) spawns its own player
## and then one per joining peer; a client receives everything from the host.
func start(lobby: bool = false) -> void:
	if _started:
		return
	_started = true
	if multiplayer.is_server():
		phase = Phase.LOBBY if lobby else Phase.RUN
		roster[multiplayer.get_unique_id()] = GameSettings.clean_name(local_name)
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		if phase == Phase.RUN:
			_add_player(multiplayer.get_unique_id())
		# Peers that connected before start() are handled now.
		for peer_id: int in multiplayer.get_peers():
			_on_peer_connected(peer_id)
		if sky != null:
			sky.changed.connect(send_sky)
	else:
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		if sky != null:
			sky.weather.rolls_enabled = false
		multiplayer.connected_to_server.connect(_request_join)
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_request_join()


## Host: ends the lobby and spawns every player, the host first, then in join order. Returns
## false on a client or outside the lobby.
func begin_run() -> bool:
	if not multiplayer.is_server() or phase != Phase.LOBBY:
		return false
	phase = Phase.RUN
	_add_player(multiplayer.get_unique_id())
	var waiting: Array[int] = []
	for peer_id: int in roster:
		if multiplayer.get_peers().has(peer_id):
			waiting.append(peer_id)
	for peer_id: int in multiplayer.get_peers():
		if not waiting.has(peer_id):
			waiting.append(peer_id)
	for peer_id: int in waiting:
		_on_peer_connected(peer_id)
	run_begun.rpc()
	run_started.emit()
	return true


## Client: sends this peer's name to the host (once; the host ignores repeats).
func _request_join() -> void:
	request_join.rpc_id(HOST_ID, local_name)


@rpc("any_peer", "call_remote", "reliable")
func request_join(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == HOST_ID or roster.has(sender) or not multiplayer.get_peers().has(sender):
		return
	roster[sender] = GameSettings.clean_name(player_name, default_name(roster))
	receive_lobby.rpc_id(sender, roster, phase == Phase.RUN)
	_share_roster(sender)


@rpc("authority", "call_remote", "reliable")
func receive_lobby(roster_data: Dictionary, in_run: bool) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	roster = clean_roster(roster_data)
	phase = Phase.RUN if in_run else Phase.LOBBY
	lobby_received.emit(in_run)


@rpc("authority", "call_remote", "reliable")
func update_roster(roster_data: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	roster = clean_roster(roster_data)
	roster_updated.emit()


@rpc("authority", "call_remote", "reliable")
func run_begun() -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	phase = Phase.RUN
	run_started.emit()


## The name for a player who gave none: "Balsero N" with the first N from the lobby's size up
## that nobody in the lobby already has.
static func default_name(current: Dictionary[int, String]) -> String:
	var number := current.size() + 1
	while current.values().has("%s %d" % [GameSettings.DEFAULT_NAME, number]):
		number += 1
	return "%s %d" % [GameSettings.DEFAULT_NAME, number]


## The int → cleaned-name pairs of a roster that arrived over the network; anything else is
## dropped.
static func clean_roster(data: Dictionary) -> Dictionary[int, String]:
	var cleaned: Dictionary[int, String] = {}
	for key: Variant in data:
		var value: Variant = data[key]
		if key is int and value is String:
			cleaned[key] = GameSettings.clean_name(value)
	return cleaned


# Host: sends the roster to every client but `except` (which already has it) and tells itself.
func _share_roster(except: int = 0) -> void:
	for peer_id: int in multiplayer.get_peers():
		if peer_id != except:
			update_roster.rpc_id(peer_id, roster)
	roster_updated.emit()


# Host: counts down the dropped players and removes each one when its time is up.
func _physics_process(delta: float) -> void:
	_resync_sky(delta)
	for peer_id: int in _dropped.keys():
		var left: float = _dropped[peer_id] - delta
		if left > 0.0:
			_dropped[peer_id] = left
		else:
			_dropped.erase(peer_id)
			_remove_player(peer_id)


## Host: whether `peer_id` dropped and its player is waiting out the countdown.
func is_dropped(peer_id: int) -> bool:
	return _dropped.has(peer_id)


## Host: seconds before a dropped client's player is removed (0 if it is not dropped).
func disconnect_time_left(peer_id: int) -> float:
	return _dropped.get(peer_id, 0.0)


## Host: the difficulty for an island set up now, from the living, connected players (dropped
## players do not count). `alive` decides who is alive; by default every connected player is,
## until the meters say a player is dead.
func island_difficulty(alive: Callable = Callable()) -> DifficultyScaling:
	var living: int = 0
	for peer_id: int in peer_ids():
		if _dropped.has(peer_id):
			continue
		var player := body(peer_id)
		var counts: bool = alive.call(player) if alive.is_valid() else is_alive(player)
		if counts:
			living += 1
	return DifficultyScaling.for_players(living)


## Whether a player is alive: true unless its meters report it dead.
static func is_alive(player: PlayerBody) -> bool:
	return player.meters == null or not player.meters.dead


## Whether this session may pause: only solo (the offline peer, one player). Co-op, and a host
## waiting alone for joiners, never pause.
func can_pause() -> bool:
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer and peer_ids().size() <= 1


## Pauses or resumes the whole simulation (every node that inherits the tree's pause: players,
## meters, creatures, patrols, weather and clock). Returns false when pausing is not allowed.
func set_paused(value: bool) -> bool:
	if value and not can_pause():
		return false
	get_tree().paused = value
	paused_changed.emit(value)
	return true


## The body of `peer_id`'s player in this session, or null.
func body(peer_id: int) -> PlayerBody:
	var found: Variant = _bodies.get(peer_id)
	return found as PlayerBody if is_instance_valid(found) else null


## The name `peer_id` plays under ("Balsero" until one is known).
func player_name(peer_id: int) -> String:
	return roster.get(peer_id, GameSettings.DEFAULT_NAME)


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
	_receive_intent(multiplayer.get_remote_sender_id(), seq, direction, run, crouch, interact, delta)


## Host: whether `peer_id` may have one more intent claiming `delta` seconds now (its intent
## count and simulated-time limits). The host's own player is trusted and never limited, so a
## solo player never loses input. Over-limit intents are dropped without a log line.
func accept_intent(peer_id: int, delta: float) -> bool:
	if peer_id == HOST_ID:
		return true
	var limits: PeerLimits = _limits.get(peer_id)
	return limits != null and limits.allow_intent(delta, clock.call())


# Host: an intent from `sender` (resolved from the RPC, never from its payload).
func _receive_intent(sender: int, seq: int, direction: Vector2, run: bool, crouch: bool, interact: bool, delta: float) -> void:
	var target := body(sender)
	if target == null or not is_valid_intent(direction, delta) or not accept_intent(sender, delta):
		return
	target.net.enqueue(seq, MoveIntent.create(direction, run, crouch, interact), delta)


## This peer's player says the quick-chat phrase in `slot` (the wheel calls it).
func say(slot: int) -> void:
	request_quick_chat.rpc_id(HOST_ID, slot)


@rpc("any_peer", "call_local", "reliable")
func request_quick_chat(slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if body(sender) == null or slot < 0 or slot >= phrases.size():
		return
	var limits: PeerLimits = _limits.get(sender)
	if limits == null or not limits.allow_quick_chat(clock.call()):
		return
	show_quick_chat.rpc(sender, slot)


@rpc("authority", "call_local", "reliable")
func show_quick_chat(peer_id: int, slot: int) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	var speaker := body(peer_id)
	if speaker == null or slot < 0 or slot >= phrases.size():
		return
	show_bubble(speaker, phrases.text(slot, locale), phrases.voice(slot))
	quick_chat_shown.emit(peer_id, slot)


## This peer's player crafts `recipe_id` at the workbench at `station_path` (relative to this
## session). The host checks and runs it; nothing changes here until the host's inventory syncs.
func craft(recipe_id: StringName, station_path: NodePath) -> void:
	request_craft.rpc_id(HOST_ID, recipe_id, station_path)


## This peer's player uses the item in `slot` (use number `use_index`), on `target_peer`'s player
## or, with 0, on themself.
func use_item(slot: int, use_index: int, target_peer: int = 0) -> void:
	request_use.rpc_id(HOST_ID, slot, use_index, target_peer)


## This peer's player deposits what they carry into the build site at `site_path` and works it.
func deposit(site_path: NodePath) -> void:
	request_deposit.rpc_id(HOST_ID, site_path)


@rpc("any_peer", "call_local", "reliable")
func request_craft(recipe_id: StringName, station_path: NodePath) -> void:
	if multiplayer.is_server():
		craft_for(_sender(), recipe_id, station_path)


@rpc("any_peer", "call_local", "reliable")
func request_use(slot: int, use_index: int, target_peer: int) -> void:
	if multiplayer.is_server():
		use_for(_sender(), slot, use_index, target_peer)


@rpc("any_peer", "call_local", "reliable")
func request_deposit(site_path: NodePath) -> void:
	if multiplayer.is_server():
		deposit_for(_sender(), site_path)


## Host: starts `peer`'s craft. Only that peer's own inventory, reach and recipe count; the
## request names no one else. Returns whether it started.
func craft_for(peer: int, recipe_id: StringName, station_path: NodePath) -> bool:
	var player := _acting_body(peer)
	if player == null:
		return false
	return player.crafter.start(player.crafter.recipe_for(recipe_id), get_node_or_null(station_path) as Node2D)


## Host: `peer` uses an item from their own slot on `target_peer`'s player (0: themself), who
## must be within reach.
func use_for(peer: int, slot: int, use_index: int, target_peer: int) -> bool:
	var player := _acting_body(peer, true)
	if player == null:
		return false
	# Downed means immobile; only a solo last stand may act, and only to stand themself up.
	if player.meters.last_stand and not (target_peer in [0, peer] and ItemUser.revives(player, slot, use_index)):
		return false
	var target: PlayerBody = null
	if target_peer != 0 and target_peer != peer:
		target = body(target_peer)
		if target == null or player.global_position.distance_to(target.global_position) > InteractionPicker.REACH_PX + PlayerBody.REACH_SLACK_PX:
			return false
	return ItemUser.use(player, slot, use_index, target)


## Host: `peer` feeds the build site at `site_path` from their own inventory and works it.
func deposit_for(peer: int, site_path: NodePath) -> bool:
	var player := _acting_body(peer)
	var site := get_node_or_null(site_path) as BuildSite
	if player == null or site == null or site.built:
		return false
	if player.global_position.distance_to(site.global_position) > InteractionPicker.REACH_PX + PlayerBody.REACH_SLACK_PX:
		return false
	site.deposit(player)
	return player.crafter.start_work(site)


# The sender of the RPC being handled; a call to ourselves (solo, or the host) has none.
func _sender() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return HOST_ID if sender == 0 else sender


# `peer`'s body if it may act now: alive and on their feet (a downed player or one in a last
# stand lies still, unless `allow_last_stand`); the host is trusted, a client is rate limited.
func _acting_body(peer: int, allow_last_stand: bool = false) -> PlayerBody:
	var player := body(peer)
	if player == null or player.meters.dead or player.meters.downed:
		return null
	if player.meters.last_stand and not allow_last_stand:
		return null
	if peer != HOST_ID:
		var limits: PeerLimits = _limits.get(peer)
		if limits == null or not limits.allow_action(clock.call()):
			return null
	return player


## Puts `text` over `speaker` (replacing a bubble already there) and plays `voice` if given.
func show_bubble(speaker: Node2D, text: String, voice: AudioStream = null) -> SpeechBubble:
	var old := speaker.get_node_or_null(NodePath(BUBBLE_NAME))
	if old != null:
		speaker.remove_child(old)
		old.queue_free()
	var bubble := SPEECH_BUBBLE_SCENE.instantiate() as SpeechBubble
	bubble.name = BUBBLE_NAME
	bubble.text = text
	bubble.voice = voice
	speaker.add_child(bubble)
	return bubble


@rpc("authority", "call_remote", "reliable")
func receive_world_state(state: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	world_state = checked_world_state(state)
	if sky != null:
		sky.apply_state(world_state)
	world_state_received.emit(world_state)


## Host: sends the clock and weather to every client. Solo has no client, so nothing is sent.
func send_sky() -> void:
	if sky == null or not multiplayer.is_server() or multiplayer.get_peers().is_empty():
		return
	_resync_left_s = sky.tuning.resync_s
	receive_sky.rpc(sky.to_state())


@rpc("authority", "call_remote", "reliable")
func receive_sky(state: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or sky == null:
		return
	sky.apply_state(checked_world_state(state))


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
	# In the lobby the join request brings the name; begin_run() spawns.
	if phase == Phase.LOBBY:
		return
	_add_player(peer_id)
	if body(peer_id) != null:
		var state: Dictionary = world_state.duplicate()
		if sky != null:
			state.merge(sky.to_state(), true)
		receive_world_state.rpc_id(peer_id, state)


# The player stays in the world, downed (draggable), until the countdown removes it. A client
# that reconnects gets a new peer id and so a new player.
func _on_peer_disconnected(peer_id: int) -> void:
	if phase == Phase.LOBBY:
		# Nobody is in the world yet: the name just leaves the roster.
		_limits.erase(peer_id)
		if roster.erase(peer_id):
			_share_roster()
		return
	var dropped := body(peer_id)
	if dropped == null or _dropped.has(peer_id):
		return
	dropped.set_downed(true)
	_limits.erase(peer_id)
	_dropped[peer_id] = DISCONNECT_DOWNED_S
	player_disconnected.emit(peer_id)


func _remove_player(peer_id: int) -> void:
	var leaving := body(peer_id)
	if leaving == null:
		return
	var last_position: Vector2 = leaving.position
	_bodies.erase(peer_id)
	player_removed.emit(peer_id, last_position)
	# Freed on the host; the spawner removes it on every client.
	leaving.queue_free()


# Client: the session is over. Players and entities go; the level shows the host-lost screen.
func _on_server_disconnected() -> void:
	_bodies.clear()
	for child: Node in players.get_children():
		child.queue_free()
	for child: Node in entities.get_children():
		child.queue_free()
	host_lost.emit()


func _add_player(peer_id: int) -> void:
	if _bodies.has(peer_id):
		return
	# Dropped players keep their body until removed but not their place: a reconnect is a new
	# peer and must fit (ENet also refuses a fourth client).
	if _bodies.size() - _dropped.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	var spot: Vector2 = Vector2.ZERO
	if not spawn_points.is_empty():
		spot = spawn_points[_joined % spawn_points.size()]
	_joined += 1
	_limits[peer_id] = PeerLimits.new()
	player_spawner.spawn({"peer": peer_id, "position": spot})


# Runs on every peer: on the host through spawn(), on clients when the host's spawn arrives.
func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data if data is Dictionary else {}
	var peer_id: int = info.get("peer", 0) if info.get("peer", 0) is int else 0
	var spot: Vector2 = info.get("position") if info.get("position") is Vector2 else Vector2.ZERO
	if not spot.is_finite():
		spot = Vector2.ZERO
	var new_body := PLAYER_SCENE.instantiate() as PlayerBody
	new_body.name = str(peer_id)
	new_body.position = spot
	new_body.terrain = terrain
	new_body.climate = climate
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


# Host: the periodic clock message between changes.
func _resync_sky(delta: float) -> void:
	if sky == null or not multiplayer.is_server():
		return
	_resync_left_s -= delta
	if _resync_left_s <= 0.0:
		send_sky()
		_resync_left_s = sky.tuning.resync_s


func _ticks_s() -> float:
	return Time.get_ticks_usec() / 1000000.0
