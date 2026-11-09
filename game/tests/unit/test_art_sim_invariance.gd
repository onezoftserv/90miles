extends GutTest
## art-pass "Drawing never changes the simulation" ("Same run with and without art"; design.md D22
## and P1), with exactly 1 player, offline: a solo sandbar with its creatures runs 600 physics
## frames of fixed intents twice, once as built and once with every node of the `art_view` group
## freed (before every frame, so art that a later spawn brings goes too), and every frame's player
## position, synced state, meters and inventory and every creature's position and state are equal.
## The player's synchronizer lists the same property paths both times, compared as lists, never as
## a count (coop-networking and survival-meters own how many there are).
## The built run walks to the three pick-ups nearest the spawn and presses E on each, then crouches
## back; its intents are recorded and the stripped run replays them exactly. Each run is built,
## stepped and freed with no frame awaited, so the engine never processes it on its own: the
## creature spawner's deferred start is called at once, every callback is stepped by hand in the
## engine's order at the physics rate, and the clock is stepped with the weather rolls off, so both
## runs are exact.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const ART_GROUP: StringName = &"art_view"
const FRAMES: int = 600
const RUN_SEED: int = 90
const PICKUPS_ON_ROUTE: int = 3
## Close enough to a pick-up that it is the nearest one in reach.
const AT_TARGET_PX: float = 3.0
## Axis dead band when steering, so the body does not jitter about a line.
const STEER_PX: float = 1.0

var island: SandbarIsland
var session: CoopSession
var body: PlayerBody
var spawner: CreatureSpawner
## Seconds per frame: the project's physics rate.
var dt: float = 1.0 / 60.0
## The built run's intent per frame, replayed by the stripped run.
var intents: Array[MoveIntent] = []
## Art nodes freed during the stripped run.
var stripped: int = 0
# The built run's route: where to walk, then whether to press E there.
var _route: Array[Vector2] = []
var _leg: int = 0
var _pressing: int = 0


func before_each() -> void:
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	intents.clear()
	stripped = 0
	NetManager.start_solo()
	WeatherManager.stop()


func after_each() -> void:
	_free_run()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.stop()
	NetManager.leave()


# --- one run -------------------------------------------------------------------------------------

# A solo sandbar built as the shell builds it (game_shell.gd _build_run), with a fixed run seed and
# the deterministic sky: day 1 at dawn, no weather rolls, the clock stepped only by _frame.
func _build() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
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
	# The spawner's start is deferred to the next frame, which never comes while the run lives: it
	# begins now, as it would then. Its queued call is dropped with the freed run.
	spawner._begin()


func _free_run() -> void:
	if is_instance_valid(session):
		remove_child(session)
		session.free()
	if is_instance_valid(island):
		remove_child(island)
		island.free()
	session = null
	island = null
	body = null
	spawner = null


# One physics frame in the engine's order (the session, its creatures, the body and its net, the
# spawner, lit fires), then the clock.
func _frame(intent: MoveIntent) -> void:
	body.intent = intent
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
	WeatherManager.sky.advance(dt)


# Every art node goes at once, as if the art had never been built.
func _strip_art() -> void:
	for node: Node in get_tree().get_nodes_in_group(ART_GROUP):
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
			stripped += 1


# --- what a frame holds --------------------------------------------------------------------------

func _sync_paths() -> PackedStringArray:
	var sync := body.get_node(^"StateSync") as MultiplayerSynchronizer
	var paths: PackedStringArray = []
	for path: NodePath in sync.replication_config.get_properties():
		paths.append(String(path))
	return paths


# The body's position, every property its synchronizer replicates (read live), its energy and
# inventory; each creature's name, kind, position, facing, state and what it carries; the pick-ups
# still lying.
func _snapshot() -> Dictionary:
	var synced: Dictionary = {}
	for path: String in _sync_paths():
		var node_path := NodePath(path)
		synced[path] = body.get_node(NodePath(node_path.get_concatenated_names())).get(node_path.get_concatenated_subnames())
	var creatures: Array = []
	for node: Node in session.entities.get_children():
		var creature := node as Creature
		if creature != null:
			creatures.append([String(creature.name), creature.data.id, creature.position, creature.facing, creature.state_id, creature.carried.duplicate()])
	var pickups: PackedStringArray = []
	for node: Node in session.pickups.get_children():
		if not node.is_queued_for_deletion():
			pickups.append(String(node.name))
	return {
		"position": body.position,
		"synced": synced,
		"energy": body.meters.energy,
		"inventory": body.inventory.to_net(),
		"creatures": creatures,
		"pickups": pickups,
	}


# --- the built run's route -----------------------------------------------------------------------

func _plan_route() -> void:
	var spawn: Vector2 = body.global_position
	var spots: Array[Vector2] = []
	for spec: Dictionary in island.built.pickups:
		spots.append(IslandLayout.cell_center(spec["cell"]))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(spawn) < b.distance_to(spawn))
	_route = spots.slice(0, PICKUPS_ON_ROUTE)
	_route.append(spawn)
	_leg = 0
	_pressing = 0


# Steers to the next spot of the route and presses E for one frame there; runs on the second leg and
# crouches home on the last.
func _steer() -> MoveIntent:
	if _leg >= _route.size():
		return MoveIntent.new()
	var last_leg: bool = _leg == _route.size() - 1
	if _pressing > 0:
		_pressing -= 1
		if _pressing == 0:
			_leg += 1
		return MoveIntent.create(Vector2.ZERO, false, false, _pressing == 1)
	var gap: Vector2 = _route[_leg] - body.global_position
	if gap.length() <= AT_TARGET_PX:
		if last_leg:
			_leg += 1
			return MoveIntent.new()
		# One frame with E held, then one released, then the next leg.
		_pressing = 2
		return MoveIntent.create(Vector2.ZERO, false, false, false)
	var direction := Vector2(_axis(gap.x), _axis(gap.y))
	return MoveIntent.create(direction.normalized(), _leg == 1, last_leg, false)


func _axis(gap: float) -> float:
	if gap > STEER_PX:
		return 1.0
	if gap < -STEER_PX:
		return -1.0
	return 0.0


# --- the test ------------------------------------------------------------------------------------

func _built_run() -> Dictionary:
	_build()
	_plan_route()
	var frames: Array[Dictionary] = []
	for i: int in FRAMES:
		var intent := _steer()
		intents.append(intent)
		_frame(intent)
		frames.append(_snapshot())
	var result := {"frames": frames, "paths": _sync_paths(), "creatures": spawner.creatures().size(), "art": get_tree().get_nodes_in_group(ART_GROUP).size()}
	_free_run()
	return result


func _stripped_run() -> Dictionary:
	_build()
	var frames: Array[Dictionary] = []
	for i: int in FRAMES:
		_strip_art()
		_frame(intents[i])
		frames.append(_snapshot())
	_strip_art()
	var result := {"frames": frames, "paths": _sync_paths(), "art": get_tree().get_nodes_in_group(ART_GROUP).size()}
	_free_run()
	return result


# The first frame whose snapshot differs between the runs, or -1.
func _first_difference(built: Array[Dictionary], bare: Array[Dictionary]) -> int:
	for i: int in mini(built.size(), bare.size()):
		if built[i] != bare[i]:
			return i
	return -1 if built.size() == bare.size() else mini(built.size(), bare.size())


# What differs, one level into nested dictionaries (the synced properties), so a failure names the
# field.
func _differing_keys(a: Dictionary, b: Dictionary, prefix: String = "") -> PackedStringArray:
	var keys: PackedStringArray = []
	for key: Variant in a:
		var other: Variant = b.get(key)
		if a[key] == other:
			continue
		if a[key] is Dictionary and other is Dictionary and prefix.is_empty():
			keys.append_array(_differing_keys(a[key], other, "%s." % key))
		else:
			keys.append("%s%s: %s with art, %s without" % [prefix, key, a[key], other])
	return keys


func test_a_solo_sandbar_runs_the_same_with_and_without_art() -> void:
	var built: Dictionary = _built_run()
	var bare: Dictionary = _stripped_run()
	var built_frames: Array[Dictionary] = built["frames"]
	var bare_frames: Array[Dictionary] = bare["frames"]
	assert_eq(built_frames.size(), FRAMES)
	assert_eq(bare_frames.size(), FRAMES)
	assert_gt(built["creatures"], 0, "the sandbar's creatures are on, as in a real run")
	var last_inventory: Array = built_frames[FRAMES - 1]["inventory"]
	assert_false(last_inventory.is_empty(), "the scripted run picked something up")
	assert_ne(built_frames[0]["position"], built_frames[FRAMES - 1]["position"], "the scripted run moved")
	assert_eq(bare["art"], 0, "every art node was freed in the stripped run")
	var first: int = _first_difference(built_frames, bare_frames)
	var detail: String = ""
	if first >= 0 and first < mini(built_frames.size(), bare_frames.size()):
		detail = "; ".join(_differing_keys(built_frames[first], bare_frames[first]))
	assert_eq(first, -1, "every frame equal with and without art (first difference: %s)" % detail)
	var built_paths: PackedStringArray = built["paths"]
	var bare_paths: PackedStringArray = bare["paths"]
	assert_false(built_paths.is_empty())
	assert_eq(bare_paths, built_paths, "the player's synchronizer lists the same property paths")
	gut.p("art nodes in the built run: %d; freed in the stripped run: %d; %d frames, %d creatures, inventory %s" % [built["art"], stripped, FRAMES, built["creatures"], last_inventory])
