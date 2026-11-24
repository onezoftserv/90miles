extends GutTest
## sound-pass over ENet on localhost (NetHarness; audio "Own events are heard only by their player",
## "World events are heard by every peer", "Pick-up cue", "The patrol motor swells over the horizon
## warning", "Loudhailer"). Each peer gets its own RunSounds and its own AudioManager instance as a
## recorder, so what each peer asked for can be told apart in one process:
## - a pick-up is heard by the player who made it and by nobody else;
## - a patrol boat's warning swells the motor on both peers at about the same level, and its alert
##   plays the loudhailer once on both;
## - a joining client's bag, arriving from the host just after the join, plays nothing.
## The sky is one autoload shared by both branches here, so the weather cues are checked across two
## processes instead (tests/manual/sound_pass_run.gd).

const LAYOUT: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const MANAGER_SCRIPT: Script = preload("res://scripts/autoload/audio_manager.gd")
const TIMEOUT_S: float = 5.0
const NIGHT_S: float = 430.0

var net: NetHarness
var spawner: CreatureSpawner
var brain: PatrolRoute
var patrol: PatrolData
## Peer id -> the ids its recorder played.
var heard: Dictionary[int, Array] = {}
## Peer id -> its RunSounds.
var listening: Dictionary[int, RunSounds] = {}
# Freed before the sessions they read, newest first.
var listeners: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.rolls_enabled = false
	heard.clear()
	listening.clear()
	listeners.clear()


func after_each() -> void:
	listeners.reverse()
	for node: Node in listeners:
		if is_instance_valid(node):
			node.free()
	listeners.clear()
	net.teardown()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()


func _setup(for_session: CoopSession) -> void:
	for_session.terrain = IslandLayout.build(LAYOUT).terrain


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return []
	assert_true(await net.settle())
	net.silence_input()
	return [host, client]


# This peer's RunSounds, playing into a recorder of its own.
func _listen(session: CoopSession) -> RunSounds:
	var peer: int = net.peer_id(session)
	var recorder: Node = MANAGER_SCRIPT.new()
	add_child(recorder)
	listeners.append(recorder)
	var ids: Array[StringName] = []
	heard[peer] = ids
	recorder.sfx_played.connect(func(id: StringName) -> void: ids.append(id))
	var sounds := RunSounds.new()
	sounds.audio = recorder
	add_child(sounds)
	listeners.append(sounds)
	sounds.bind(session, peer)
	listening[peer] = sounds
	return sounds


func _count(peer: int, id: StringName) -> int:
	return (heard.get(peer, []) as Array).count(id)


func _motor(peer: int) -> float:
	return listening[peer].audio.loop_target(&"patrol_motor")


# The host's spawner on the sandbar at night for one player, and its boat, with the boat's and the
# spawner's physics off: the test sets the clock (as test_patrol_cues does).
func _spawn_boat(host: CoopSession) -> Creature:
	WeatherManager.sky.start_at(NIGHT_S)
	spawner = CreatureSpawner.new()
	spawner.name = SandbarIsland.CREATURES_NAME
	host.add_child(spawner)
	spawner.setup(host, LAYOUT)
	spawner.party_size = 1
	spawner.world.phase = DataEnums.DayPhase.NIGHT
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.spawn_permanent()
	var made: Creature = spawner.creatures(&"patrol_boat")[0]
	made.set_physics_process(false)
	spawner.set_physics_process(false)
	brain = made.brain as PatrolRoute
	patrol = made.data.patrol
	return made


func _theirs(client: CoopSession, creature: Creature) -> Creature:
	return client.entities.get_node_or_null(NodePath(creature.name)) as Creature


# The host and the client share one scene tree here, so the host's world would also see the client
# branch's copies of the bodies (a real host sees only its own). The copies leave the players group.
func _client_bodies_are_not_players(client: CoopSession) -> void:
	for peer: int in client.peer_ids():
		client.body(peer).remove_from_group(PlayerBody.GROUP)


func test_the_hosts_pick_up_is_heard_by_the_host_only() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_listen(host)
	_listen(client)
	assert_eq(listening[CoopSession.HOST_ID].settle_s, 0.0, "the host trusts its own state at once")
	assert_eq(listening[client_id].settle_s, RunSounds.CLIENT_SETTLE_S)
	await wait_seconds(RunSounds.CLIENT_SETTLE_S + 0.2)
	host.body(CoopSession.HOST_ID).inventory.add(&"driftwood", 1)
	await wait_seconds(0.5)
	assert_eq(_count(CoopSession.HOST_ID, &"pickup"), 1, "Yuni hears her own pick-up")
	assert_eq(_count(client_id, &"pickup"), 0, "Papo does not")


func test_the_clients_pick_up_is_heard_by_the_client_only() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_listen(host)
	_listen(client)
	await wait_seconds(RunSounds.CLIENT_SETTLE_S + 0.2)
	host.body(client_id).inventory.add(&"coco", 1)
	var heard_it := func() -> bool: return _count(client_id, &"pickup") == 1
	assert_true(await wait_until(heard_it, TIMEOUT_S), "Papo hears his pick-up when the host's state lands")
	assert_eq(_count(CoopSession.HOST_ID, &"pickup"), 0, "Yuni does not")


func test_a_joining_clients_bag_arriving_from_the_host_plays_nothing() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var client_id: int = net.peer_id(client)
	_listen(client)
	host.body(client_id).inventory.add(&"driftwood", 4)
	var arrived := func() -> bool: return InventoryGain.counts(net.own_body(client).inventory).get(&"driftwood", 0) == 4
	assert_true(await wait_until(arrived, TIMEOUT_S), "the bag arrives")
	assert_eq(_count(client_id, &"pickup"), 0, "an arriving bag is not a pick-up")
	await wait_seconds(RunSounds.CLIENT_SETTLE_S + 0.2)
	host.body(client_id).inventory.add(&"driftwood", 1)
	var heard_it := func() -> bool: return _count(client_id, &"pickup") == 1
	assert_true(await wait_until(heard_it, TIMEOUT_S), "a real pick-up after the join is heard")


func test_a_patrol_warning_swells_the_motor_on_both_peers() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_listen(host)
	_listen(client)
	var made: Creature = _spawn_boat(host)
	brain.set_clock(10.0)
	made.advance(0.0)
	assert_eq(made.state_id, PatrolRoute.State.HORIZON)
	var both := func() -> bool: return _motor(CoopSession.HOST_ID) > 0.0 and _motor(client_id) > 0.0
	assert_true(await wait_until(both, TIMEOUT_S), "both peers hear the motor during the warning")
	await wait_seconds(0.3)
	var host_db: float = linear_to_db(_motor(CoopSession.HOST_ID))
	var client_db: float = linear_to_db(_motor(client_id))
	assert_almost_eq(client_db, host_db, 2.0, "about the same level (the client's clock runs on between syncs)")
	brain.set_clock(patrol.horizon_warning_s + patrol.route_lap_s + 1.0)
	made.advance(0.0)
	assert_eq(made.state_id, PatrolRoute.State.AWAY)
	var gone := func() -> bool: return _motor(CoopSession.HOST_ID) == 0.0 and _motor(client_id) == 0.0
	assert_true(await wait_until(gone, TIMEOUT_S), "the motor goes on both when the boat leaves")


func test_a_patrol_alert_plays_the_loudhailer_once_on_both_peers() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	_client_bodies_are_not_players(client)
	var made: Creature = _spawn_boat(host)
	brain.set_clock(patrol.horizon_warning_s + 5.0)
	made.advance(0.0)
	assert_true(await wait_until(func() -> bool: return _theirs(client, made) != null, TIMEOUT_S))
	_listen(host)
	_listen(client)
	await wait_seconds(RunSounds.CLIENT_SETTLE_S + 0.2)
	var player: PlayerBody = host.body(CoopSession.HOST_ID)
	# On the sand (guardacostas-capture: a spotted swimmer in deep water is chased, not locked).
	player.global_position = IslandLayout.cell_center(IslandLayout.build(LAYOUT).solo_spawn)
	player.movement_state = MovementStep.Move.WALK
	made.world.spawner = Callable()
	brain.spot(player, &"sight")
	assert_eq(made.alert_serial, 1)
	var both := func() -> bool: return _count(CoopSession.HOST_ID, &"loudhailer") == 1 and _count(client_id, &"loudhailer") == 1
	assert_true(await wait_until(both, TIMEOUT_S), "the call is heard on both peers")
	await wait_seconds(0.3)
	assert_eq(_count(CoopSession.HOST_ID, &"loudhailer"), 1, "once")
	assert_eq(_count(client_id, &"loudhailer"), 1, "once")
