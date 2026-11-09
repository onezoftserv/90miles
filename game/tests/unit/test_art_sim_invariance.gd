extends GutTest
## art-pass "Drawing never changes the simulation" ("Same run with and without art"; design.md D22,
## P1, K22 and K34), with exactly 1 player, offline: a solo sandbar with its creatures runs 600
## physics frames of fixed intents twice, and every frame's player position, synced state, meters
## and inventory and every creature's position and state are equal.
## - The built run steps the art too: after the simulation's callbacks, each frame calls the
##   _physics_process and then the _process of every node in or under the `art_view` group whose
##   callback is on, as the engine would.
## - In the stripped run art never runs: a node entering the tree in or under `art_view` loses its
##   script before its _ready, and every such node is freed before every frame (so art that a later
##   spawn brings goes too). Code in an art script's _enter_tree would run before that, so the built
##   run names any art script that has one.
## - The player's synchronizer lists the same property paths both times, compared as lists, never as
##   a count (coop-networking and survival-meters own how many there are).
## The guard is itself tested: a bad look planted under the player in both runs, writing the
## player's thirst as it becomes ready, each physics frame or each process frame, makes the runs
## differ on the first frame.
## The built run walks to the three pick-ups nearest the spawn and presses E on each, then crouches
## back; its intents are recorded and the stripped run replays them exactly. Each run is built,
## stepped and freed with no frame awaited, so the engine never processes it on its own: the
## creature spawner's deferred start is called at once, every callback is stepped by hand in the
## engine's order at the physics rate, and the clock is stepped with the weather rolls off, so both
## runs are exact.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const WRITING_LOOK: GDScript = preload("res://tests/fixtures/art/sim/sim_writing_look.gd")
const ENTER_TREE_LOOK: GDScript = preload("res://tests/fixtures/art/sim/enter_tree_look.gd")
const ART_GROUP: StringName = &"art_view"
const FRAMES: int = 600
## Enough frames for a planted bad look to show.
const SHORT_FRAMES: int = 30
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
## Art nodes whose script the stripped run detached as they entered the tree.
var disarmed: int = 0
## Art callbacks the runs called.
var ticked: int = 0
## Bad looks planted under the player in both runs, by where each writes (the guard's own tests):
## inside a plain holder, so each enters the tree with its parent's subtree as scene-built art does,
## or added to the player on its own.
var planted: Array[StringName] = []
var planted_alone: Array[StringName] = []
# The built run's route: where to walk, then whether to press E there.
var _route: Array[Vector2] = []
var _leg: int = 0
var _pressing: int = 0


func before_each() -> void:
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	intents.clear()
	planted.clear()
	planted_alone.clear()
	stripped = 0
	disarmed = 0
	ticked = 0
	NetManager.start_solo()
	WeatherManager.stop()


func after_each() -> void:
	_stop_disarming()
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
	for writes_in: StringName in planted:
		var holder := Node2D.new()
		holder.add_child(WRITING_LOOK.new(writes_in) as Node)
		body.add_child(holder)
	for writes_in: StringName in planted_alone:
		body.add_child(WRITING_LOOK.new(writes_in) as Node)
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
# spawner, lit fires, then the art's own callbacks), then the clock.
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
	_tick_art()
	WeatherManager.sky.advance(dt)


# The art's own callbacks, as the engine runs them after the simulation's: every node in or under
# the art_view group whose callback is on, every _physics_process first, then every _process.
func _tick_art() -> void:
	var art: Array[Node] = _art_in_run()
	for node: Node in art:
		if node.is_physics_processing() and node.has_method(&"_physics_process"):
			node.call(&"_physics_process", dt)
			ticked += 1
	for node: Node in art:
		if node.is_processing() and node.has_method(&"_process"):
			node.call(&"_process", dt)
			ticked += 1


# Every node of this run in or under the art_view group, each once, in tree order.
func _art_in_run() -> Array[Node]:
	var art: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(ART_GROUP):
		if _in_run(node) and not _has_art_ancestor(node):
			art.append(node)
			art.append_array(node.find_children("*", "", true, false))
	return art


func _in_run(node: Node) -> bool:
	return (is_instance_valid(session) and session.is_ancestor_of(node)) or (is_instance_valid(island) and island.is_ancestor_of(node))


func _has_art_ancestor(node: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent.is_in_group(ART_GROUP):
			return true
		parent = parent.get_parent()
	return false


# Every art node goes at once, as if the art had never been built.
func _strip_art() -> void:
	for node: Node in get_tree().get_nodes_in_group(ART_GROUP):
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
			stripped += 1


func _start_disarming() -> void:
	get_tree().node_added.connect(_disarm)


func _stop_disarming() -> void:
	if get_tree().node_added.is_connected(_disarm):
		get_tree().node_added.disconnect(_disarm)


# In the stripped run art never runs: a node entering the tree in or under the art_view group loses
# its script before its _ready, so none of its callbacks or signal handlers run, and _strip_art frees
# it before the next frame. Its _enter_tree has run already: _scripts_with_enter_tree covers that.
func _disarm(node: Node) -> void:
	if not node.is_in_group(ART_GROUP) and not _has_art_ancestor(node):
		return
	if node.get_script() != null:
		node.set_script(null)
	disarmed += 1


# The scripts of `nodes` that have an _enter_tree (their own or inherited).
func _scripts_with_enter_tree(nodes: Array[Node]) -> PackedStringArray:
	var found: PackedStringArray = []
	for node: Node in nodes:
		var script := node.get_script() as Script
		if script == null or found.has(script.resource_path):
			continue
		for method: Dictionary in script.get_script_method_list():
			if method["name"] == "_enter_tree":
				found.append(script.resource_path)
				break
	return found


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


# --- the two runs --------------------------------------------------------------------------------

func _built_run(frames: int) -> Dictionary:
	_build()
	_plan_route()
	var enter_tree: PackedStringArray = _scripts_with_enter_tree(_art_in_run())
	var snapshots: Array[Dictionary] = []
	for i: int in frames:
		var intent := _steer()
		intents.append(intent)
		_frame(intent)
		snapshots.append(_snapshot())
	var result := {"frames": snapshots, "paths": _sync_paths(), "creatures": spawner.creatures().size(), "art": _art_in_run().size(), "enter_tree": enter_tree}
	_free_run()
	return result


func _stripped_run(frames: int) -> Dictionary:
	_start_disarming()
	_build()
	var snapshots: Array[Dictionary] = []
	for i: int in frames:
		_strip_art()
		_frame(intents[i])
		snapshots.append(_snapshot())
	_strip_art()
	var result := {"frames": snapshots, "paths": _sync_paths(), "art": get_tree().get_nodes_in_group(ART_GROUP).size()}
	_stop_disarming()
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


# The first difference between the runs, described.
func _detail(built_frames: Array[Dictionary], bare_frames: Array[Dictionary], first: int) -> String:
	if first < 0 or first >= mini(built_frames.size(), bare_frames.size()):
		return ""
	return "; ".join(_differing_keys(built_frames[first], bare_frames[first]))


# --- the tests -----------------------------------------------------------------------------------

func test_a_solo_sandbar_runs_the_same_with_and_without_art() -> void:
	var built: Dictionary = _built_run(FRAMES)
	var bare: Dictionary = _stripped_run(FRAMES)
	var built_frames: Array[Dictionary] = built["frames"]
	var bare_frames: Array[Dictionary] = bare["frames"]
	assert_eq(built_frames.size(), FRAMES)
	assert_eq(bare_frames.size(), FRAMES)
	assert_gt(built["creatures"], 0, "the sandbar's creatures are on, as in a real run")
	var last_inventory: Array = built_frames[FRAMES - 1]["inventory"]
	assert_false(last_inventory.is_empty(), "the scripted run picked something up")
	assert_ne(built_frames[0]["position"], built_frames[FRAMES - 1]["position"], "the scripted run moved")
	assert_eq(bare["art"], 0, "every art node was freed in the stripped run")
	assert_eq(built["enter_tree"], PackedStringArray(), "no art script has an _enter_tree, which would run before the stripped run detaches it")
	var first: int = _first_difference(built_frames, bare_frames)
	assert_eq(first, -1, "every frame equal with and without art (first difference: %s)" % _detail(built_frames, bare_frames, first))
	var built_paths: PackedStringArray = built["paths"]
	var bare_paths: PackedStringArray = bare["paths"]
	assert_false(built_paths.is_empty())
	assert_eq(bare_paths, built_paths, "the player's synchronizer lists the same property paths, art never having run in the stripped run")
	gut.p("art nodes in the built run: %d; art callbacks run: %d; disarmed and freed in the stripped run: %d and %d; %d frames, %d creatures, inventory %s" % [built["art"], ticked, disarmed, stripped, FRAMES, built["creatures"], last_inventory])


# The guard itself: a bad look planted under the player in both runs makes them differ on the first
# frame, naming the player's thirst, and was disarmed in the stripped run.
func _assert_caught(writes_in: StringName, alone: bool = false) -> void:
	if alone:
		planted_alone.append(writes_in)
	else:
		planted.append(writes_in)
	var built: Dictionary = _built_run(SHORT_FRAMES)
	var bare: Dictionary = _stripped_run(SHORT_FRAMES)
	var built_frames: Array[Dictionary] = built["frames"]
	var bare_frames: Array[Dictionary] = bare["frames"]
	var first: int = _first_difference(built_frames, bare_frames)
	assert_eq(first, 0, "a look writing thirst in %s is caught on the first frame" % writes_in)
	assert_string_contains(_detail(built_frames, bare_frames, first), "SurvivalMeters:thirst")
	assert_gt(disarmed, 0, "the planted look was disarmed in the stripped run")
	assert_eq(bare["art"], 0)


func test_the_guard_catches_a_look_that_writes_as_it_becomes_ready() -> void:
	_assert_caught(&"ready")


func test_the_guard_catches_a_look_that_writes_each_physics_frame() -> void:
	_assert_caught(&"physics_process")


func test_the_guard_catches_a_look_that_writes_each_process_frame() -> void:
	_assert_caught(&"process")


func test_the_guard_catches_a_look_added_to_the_player_on_its_own() -> void:
	_assert_caught(&"ready", true)


func test_the_guard_names_an_art_script_with_an_enter_tree() -> void:
	var with_enter_tree := autofree(ENTER_TREE_LOOK.new()) as Node
	var without := autofree(WRITING_LOOK.new(&"process")) as Node
	assert_true(with_enter_tree.is_in_group(ART_GROUP))
	var nodes: Array[Node] = [with_enter_tree, without]
	assert_eq(_scripts_with_enter_tree(nodes), PackedStringArray([ENTER_TREE_LOOK.resource_path]))
