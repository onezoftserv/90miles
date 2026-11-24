extends GutTest
## sound-pass audio "Audio never changes the simulation" ("Same run with and without sound"), with
## exactly 1 player, offline. A solo sandbar at night, its patrol boat 6 s before the end of its
## horizon warning, runs 600 physics frames of fixed intents twice, stepped by hand in the engine's
## order as test_art_sim_invariance does:
## - once with RunSounds bound to the run and stepped after the simulation every frame;
## - once without it.
## Both runs go through the same pick-up, crab pinch, fall in thirst, the boat's lap and an alert.
## Every frame's player, meters, inventory, synced state, creatures, pick-ups and sky are equal. The
## sound run's own AudioManager heard the cues, so the comparison covers them, and a sound layer
## that writes to the run is caught (the guard's own test). Each run is built,
## stepped and freed with no frame awaited, so the engine never processes it on its own.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const MANAGER_SCRIPT: Script = preload("res://scripts/autoload/audio_manager.gd")
const FRAMES: int = 600
const RUN_SEED: int = 90
## Seconds since dawn at night.
const NIGHT_S: float = 430.0
## Seconds left of the boat's horizon warning when the runs start.
const WARNING_LEFT_S: float = 6.0
const PICKUP_FRAME: int = 30
const PINCH_FRAME: int = 120
const THIRST_FRAME: int = 200
const ALERT_FRAME: int = 480


## The guard's own check: sound that writes to the run (a sip of thirst each frame) must be caught.
class MeddlingSounds extends RunSounds:
	func step(delta: float) -> void:
		super.step(delta)
		var own: PlayerBody = session.body(local_peer)
		if own != null:
			own.meters.thirst -= 0.01

var island: SandbarIsland
var session: CoopSession
var body: PlayerBody
var spawner: CreatureSpawner
var sounds: RunSounds
var recorder: Node
var dt: float = 1.0 / 60.0
var played: Array[StringName] = []
var loudest_motor: float = 0.0
var loudest_night: float = 0.0
## The guard test swaps in MeddlingSounds.
var meddling: bool = false


func before_each() -> void:
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	played.clear()
	loudest_motor = 0.0
	loudest_night = 0.0
	meddling = false
	NetManager.start_solo()
	WeatherManager.stop()


func after_each() -> void:
	_free_run()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.stop()
	NetManager.leave()


# --- one run -------------------------------------------------------------------------------------

func _build(with_sound: bool) -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(NIGHT_S)
	WeatherManager.sky.weather.rolls_enabled = false
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.sky = WeatherManager.sky
	session.world_state = {"run_seed": RUN_SEED}
	session.spawn_points = island.spawn_points(true)
	add_child(session)
	island.furnish(session)
	session.start()
	island.place_pickups(session)
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	spawner = session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner._begin()
	spawner.apply_phase(WeatherManager.phase())
	for boat: Creature in spawner.creatures(&"patrol_boat"):
		(boat.brain as PatrolRoute).set_clock(boat.data.patrol.horizon_warning_s - WARNING_LEFT_S)
		boat.advance(0.0)
	if with_sound:
		recorder = MANAGER_SCRIPT.new()
		add_child(recorder)
		recorder.sfx_played.connect(func(id: StringName) -> void: played.append(id))
		sounds = MeddlingSounds.new() if meddling else RunSounds.new()
		sounds.audio = recorder
		add_child(sounds)
		sounds.bind(session, CoopSession.HOST_ID)


func _free_run() -> void:
	for node: Node in [sounds, recorder, session, island]:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	sounds = null
	recorder = null
	session = null
	island = null
	body = null
	spawner = null


func _intent(frame: int) -> MoveIntent:
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.ZERO]
	return MoveIntent.create(directions[floori(frame / 100.0) % directions.size()], false, false, false)


# One physics frame in the engine's order, the run's events at their frames, the sound (if any)
# after the simulation, then the clock.
func _frame(frame: int) -> void:
	body.intent = _intent(frame)
	if frame == PICKUP_FRAME:
		var items: Array[Node] = session.pickups.get_children()
		items.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
		(items[0] as WorldItem).interactable.interacted.emit(body)
	if frame == PINCH_FRAME:
		spawner.world.pinch(body, GameState.content.get_entry(&"creatures", &"land_crab") as CreatureData)
	if frame == THIRST_FRAME:
		body.meters.thirst = 25.0
	if frame == ALERT_FRAME:
		for boat: Creature in spawner.creatures(&"patrol_boat"):
			(boat.brain as PatrolRoute).spot(body, &"sight")
	session._physics_process(dt)
	for creature: Creature in spawner.creatures():
		creature._physics_process(dt)
	body._physics_process(dt)
	body.net._physics_process(dt)
	spawner._physics_process(dt)
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		var fire := node as Fire
		if fire != null and session.is_ancestor_of(fire):
			fire._physics_process(dt)
	if sounds != null:
		sounds.step(dt)
		recorder.step_loops(dt)
		loudest_motor = maxf(loudest_motor, recorder.loop_target(&"patrol_motor"))
		loudest_night = maxf(loudest_night, recorder.loop_target(&"night"))
	WeatherManager.sky.advance(dt)


func _snapshot() -> Dictionary:
	var sync := body.get_node(^"StateSync") as MultiplayerSynchronizer
	var synced: Dictionary = {}
	for path: NodePath in sync.replication_config.get_properties():
		synced[String(path)] = body.get_node(NodePath(path.get_concatenated_names())).get(path.get_concatenated_subnames())
	var creatures: Array = []
	for node: Node in session.entities.get_children():
		var creature := node as Creature
		if creature != null:
			creatures.append([String(creature.name), creature.data.id, creature.position, creature.facing, creature.state_id,
				creature.carried.duplicate(), creature.route_t, creature.beam, creature.alert_serial, creature.light_on])
	var pickups: PackedStringArray = []
	for node: Node in session.pickups.get_children():
		if not node.is_queued_for_deletion():
			pickups.append(String(node.name))
	return {
		"position": body.position,
		"synced": synced,
		"meters": [body.meters.health, body.meters.thirst, body.meters.hunger, body.meters.energy, body.meters.heat],
		"inventory": body.inventory.to_net(),
		"creatures": creatures,
		"pickups": pickups,
		"sky": [WeatherManager.sky.clock.time_of_day_s, WeatherManager.weather_id()],
	}


func _run(with_sound: bool) -> Array[Dictionary]:
	_build(with_sound)
	var snapshots: Array[Dictionary] = []
	for frame: int in FRAMES:
		_frame(frame)
		snapshots.append(_snapshot())
	_free_run()
	return snapshots


func test_the_same_run_with_and_without_sound_is_the_same() -> void:
	var heard: Array[Dictionary] = _run(true)
	var silent: Array[Dictionary] = _run(false)
	assert_eq(heard.size(), FRAMES)
	assert_eq(silent.size(), FRAMES)
	var first_difference: int = -1
	for i: int in FRAMES:
		if heard[i] != silent[i]:
			first_difference = i
			break
	assert_eq(first_difference, -1, "every frame equal (first difference at frame %d)" % first_difference)
	if first_difference >= 0:
		assert_eq(heard[first_difference], silent[first_difference])


func test_sound_that_writes_to_the_run_is_caught() -> void:
	meddling = true
	var heard: Array[Dictionary] = _run(true)
	meddling = false
	var silent: Array[Dictionary] = _run(false)
	assert_ne(heard[1], silent[1], "a sound layer that changes thirst differs by the second frame")


func test_the_sound_run_heard_its_cues() -> void:
	_run(true)
	assert_true(played.has(&"pickup"), "the pick-up was heard: %s" % [played])
	assert_true(played.has(&"thirst_low"), "the fall in thirst was heard")
	assert_true(played.has(&"loudhailer"), "the alert was heard")
	assert_gt(loudest_motor, 0.0, "the patrol motor was heard")
	assert_gt(loudest_night, 0.0, "the night was heard")
