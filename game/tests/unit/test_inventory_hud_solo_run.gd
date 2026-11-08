extends GutTest
## inventory-hud "A solo run is playable from the HUD" with exactly 1 player, offline: a real
## sandbar run through the game shell, its creatures on, finished by pressing and releasing the
## named input actions alone (move_*, interact, slot_n, use_item), as a player at the keyboard
## would, reading only what the HUD shows (the prompt's target, the strip). The player picks up the
## hut's knife, climbs a palm that is not a gull's nest, drinks its coconut out of the gulls' sight,
## places a fire site from the bench's crafting list and builds it, gathers and deposits the raft's
## 6 driftwood, 2 inner tubes and 3 rope, works the raft and launches it.
## The sandbar holds 8 driftwood and the fire and the raft take 9, so, as in a real solo run, the
## player sits out one squall, whose end puts the beach driftwood back (sandbar-island); the weather
## rolls are switched off and that squall is started and ended by the test, so the run is the same
## every time. Frames are stepped by hand in the engine's order at 30 Hz with no frame awaited
## after the creatures' spawn, so the run is exact and fast.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_inventory_hud_solo_run_settings.cfg"
const DT: float = 1.0 / 30.0
const TILE: float = 16.0
## Close enough to an interactable that it is the nearest one in reach.
const AT_TARGET_PX: float = 3.0
## Close enough to a path's cell centre to head for the next.
const AT_WAYPOINT_PX: float = 3.0
## Axis dead band when steering, so the body does not jitter about a line.
const STEER_PX: float = 1.0
## Frames a walk may take per pixel of its straight-line distance, and at least.
const FRAMES_PER_PX: float = 2.0
const MIN_WALK_FRAMES: int = 120
## A gull takes held food within 8 tiles of its nest (seagull.tres sight_radius_tiles); the
## coconut is drunk farther away than that, with a tile to spare.
const GULL_SIGHT_TILES: float = 8.0
const SIGHT_MARGIN_TILES: float = 1.0
const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const INTERACT: StringName = &"interact"
const USE: StringName = &"use_item"
const RAFT_INPUTS: Dictionary[StringName, int] = {&"driftwood": 6, &"inner_tube": 2, &"rope": 3}

var shell: GameShell
var session: CoopSession
var island: SandbarIsland
var body: PlayerBody
var hud: RunHud
var spawner: CreatureSpawner
var land: AStarGrid2D
var min_thirst: float = INF
var frames: int = 0
var _pressed: Dictionary[StringName, bool] = {}


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for action: StringName in _pressed.keys():
		_act(action, false)
	_pressed.clear()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# --- the run's frame -----------------------------------------------------------------------------

# One 30 Hz frame in the engine's order: physics (the input to an intent, the host stepping the body
# with its interactions, its meters and crafting, the creatures, fires), then process (the clock and
# the weather, the HUD).
func _frame() -> void:
	body.player_input._physics_process(DT)
	body.net._physics_process(DT)
	body._physics_process(DT)
	spawner._physics_process(DT)
	for creature: Creature in spawner.creatures():
		creature._physics_process(DT)
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		var fire := node as Fire
		if fire != null:
			fire._physics_process(DT)
	hud.prompt._physics_process(DT)
	WeatherManager._process(DT)
	hud._process(DT)
	hud.strip._process(DT)
	hud.craft_list._process(DT)
	hud.marks._process(DT)
	(body.get_node(^"BodyLook") as BodyLook)._process(DT)
	min_thirst = minf(min_thirst, body.meters.thirst)
	frames += 1


func _frames(count: int) -> void:
	for i: int in count:
		_frame()


func _seconds(seconds: float) -> void:
	_frames(ceili(seconds / DT))


# Presses or lets go of a named action, as the engine would read a key.
func _act(action: StringName, pressed: bool) -> void:
	if _pressed.get(action, false) == pressed:
		return
	_pressed[action] = pressed
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(action: StringName) -> void:
	_act(action, true)
	_frame()
	_act(action, false)
	_frame()


func _hold(action: StringName, seconds: float) -> void:
	_act(action, true)
	_seconds(seconds)
	_act(action, false)
	_frame()


# --- walking -------------------------------------------------------------------------------------

func _build_land() -> void:
	land = AStarGrid2D.new()
	land.region = Rect2i(Vector2i.ZERO, island.built.size)
	land.cell_size = Vector2.ONE
	land.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	land.update()
	for y: int in island.built.size.y:
		for x: int in island.built.size.x:
			var cell := Vector2i(x, y)
			land.set_point_solid(cell, TerrainQuery.is_water(island.terrain.terrain_at(cell)))


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


func _steer(toward: Vector2) -> void:
	var gap: Vector2 = toward - body.global_position
	_act(&"move_right", gap.x > STEER_PX)
	_act(&"move_left", gap.x < -STEER_PX)
	_act(&"move_down", gap.y > STEER_PX)
	_act(&"move_up", gap.y < -STEER_PX)


func _stop() -> void:
	for action: StringName in MOVES:
		_act(action, false)


# Walks over land, cell centre to cell centre, to within `within_px` of `goal`, holding only the
# move actions. Returns false if it took too long.
func _walk_to(goal: Vector2, within_px: float = AT_TARGET_PX) -> bool:
	var path := land.get_id_path(_cell_of(body.global_position), _cell_of(goal))
	var waypoints: Array[Vector2] = []
	for i: int in range(1, path.size() - 1):
		waypoints.append(IslandLayout.cell_center(path[i]))
	waypoints.append(goal)
	var budget: int = maxi(MIN_WALK_FRAMES, ceili(body.global_position.distance_to(goal) * FRAMES_PER_PX * 2.0))
	for i: int in waypoints.size():
		var tolerance: float = within_px if i == waypoints.size() - 1 else AT_WAYPOINT_PX
		while body.global_position.distance_to(waypoints[i]) > tolerance:
			_steer(waypoints[i])
			_frame()
			budget -= 1
			if budget <= 0:
				_stop()
				return false
	_stop()
	_frame()
	return true


# --- what the player does ------------------------------------------------------------------------

func _lying(item_id: StringName) -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == item_id and not item.is_queued_for_deletion() and item.interactable.enabled:
			found.append(item)
	return found


func _nearest(items: Array[WorldItem]) -> WorldItem:
	var best: WorldItem = null
	for item: WorldItem in items:
		if best == null or body.global_position.distance_to(item.global_position) < body.global_position.distance_to(best.global_position):
			best = item
	return best


# Walks to the nearest `item_id` lying on the island and presses E once on it.
func _pick_up(item_id: StringName) -> void:
	var item := _nearest(_lying(item_id))
	assert_not_null(item, "a %s lies on the island" % item_id)
	if item == null:
		return
	var before: int = body.inventory.count_id(item_id)
	var count: int = item.count
	assert_true(_walk_to(item.global_position), "walked to the %s at %s" % [item_id, _cell_of(item.global_position)])
	_frame()
	assert_same(hud.prompt.target, item.interactable, "the prompt is over the %s" % item_id)
	_tap(INTERACT)
	assert_eq(body.inventory.count_id(item_id), before + count, "E picked up the %s" % item_id)


func _nest_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for index: int in island.layout.nest_palms:
		spots.append(IslandLayout.cell_center(island.built.palms[index]))
	return spots


func _out_of_gull_sight(at: Vector2) -> bool:
	for nest: Vector2 in _nest_spots():
		if at.distance_to(nest) <= (GULL_SIGHT_TILES + SIGHT_MARGIN_TILES) * TILE:
			return false
	return true


# The nearest land cell out of the gulls' sight.
func _safe_spot() -> Vector2:
	var best := body.global_position
	var best_distance: float = INF
	for y: int in island.built.size.y:
		for x: int in island.built.size.x:
			var cell := Vector2i(x, y)
			var spot := IslandLayout.cell_center(cell)
			if land.is_point_solid(cell) or not _out_of_gull_sight(spot):
				continue
			var distance: float = body.global_position.distance_to(spot)
			if distance < best_distance:
				best = spot
				best_distance = distance
	return best


# The palm with coconuts nearest the player that is not a gull's nest.
func _climbable_palm() -> Palm:
	var palms := island.get_node(^"Palms")
	var best: Palm = null
	for i: int in palms.get_child_count():
		var palm := palms.get_child(i) as Palm
		if island.layout.nest_palms.has(i) or palm.coconuts <= 0:
			continue
		if best == null or body.global_position.distance_to(palm.global_position) < body.global_position.distance_to(best.global_position):
			best = palm
	return best


func _slot_of(item_id: StringName) -> int:
	for i: int in body.inventory.slots.size():
		if body.inventory.slots[i].item_id == item_id:
			return i
	return -1


func _fires() -> Array[Fire]:
	var lit: Array[Fire] = []
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		if node is Fire and session.is_ancestor_of(node):
			lit.append(node as Fire)
	return lit


func _site_of(recipe_id: StringName) -> BuildSite:
	for node: Node in get_tree().get_nodes_in_group(BuildSite.GROUP):
		var site := node as BuildSite
		if site != null and session.is_ancestor_of(site) and not site.built and site.recipe != null and site.recipe.id == recipe_id:
			return site
	return null


# --- the run -------------------------------------------------------------------------------------

func _start() -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	session = shell.session
	island = shell.island
	body = session.body(CoopSession.HOST_ID)
	hud = shell.hud
	# The deterministic weather: no rolls; the one squall below is started by hand.
	WeatherManager.sky.weather.rolls_enabled = false
	_build_land()


func test_a_solo_player_finishes_the_sandbar_from_inputs_alone() -> void:
	_start()
	# The creature spawner starts on the next frame, as in a real run.
	await wait_physics_frames(2)
	spawner = session.get_node(^"Creatures") as CreatureSpawner
	assert_true(island.with_creatures, "creatures on, as in a real run")
	var nests := _nest_spots()
	var gulls := spawner.creatures(&"seagull")
	assert_gt(gulls.size(), 0, "gulls at the nests")
	for gull: Creature in gulls:
		assert_has(nests, gull.nest, "every gull nests at a nest palm")
	assert_true(body.player_input.enabled, "the body reads the keyboard")
	assert_true(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "offline: no socket, no port")
	min_thirst = body.meters.thirst

	# The hut: the knife, its two driftwood and two rope; dry grass and a beach driftwood nearby.
	_pick_up(&"knife")
	for item_id: StringName in [&"driftwood", &"driftwood", &"rope", &"driftwood", &"dry_grass"]:
		_pick_up(item_id)
	assert_eq(body.inventory.count_id(&"driftwood"), 3, "the fire's 3 driftwood")

	# The bench: E opens the list, E chooses "Fogata" and the site appears at the player's feet.
	var bench := session.get_node(^"HutWorkbench") as Workbench
	assert_true(_walk_to(bench.global_position + Vector2(0.0, 10.0)), "walked to the bench")
	_frame()
	assert_same(hud.prompt.target.get_parent(), bench, "the prompt is over the bench")
	_tap(INTERACT)
	assert_true(hud.craft_list.is_open(), "E at the bench opens the crafting list")
	assert_eq(hud.craft_list.row_texts()[hud.craft_list.highlighted], "Fogata", "the fire is highlighted")
	_tap(INTERACT)
	assert_false(hud.craft_list.is_open(), "the choice closes the list")
	var fire_site := _site_of(&"fire")
	assert_not_null(fire_site, "a fire site at the player's feet")
	if fire_site == null:
		return
	assert_true(body.global_position.distance_to(fire_site.global_position) < TILE, "under the player")
	assert_eq(fire_site.deposited.get(&"driftwood", 0), 0, "the choosing E deposited nothing")
	_frame()
	assert_same(hud.prompt.target, fire_site.interactable, "the prompt moves to the site")
	_tap(INTERACT)
	assert_true(fire_site.inputs_complete(), "E deposited the driftwood and the dry grass")
	for i: int in ceili(40.0 / DT):
		if not _fires().is_empty():
			break
		_frame()
	assert_eq(_fires().size(), 1, "the fire is built and lit")

	# The palm: a 2 s climb gives a coconut; it is drunk out of the gulls' sight with the knife.
	var palm := _climbable_palm()
	assert_not_null(palm, "a palm with coconuts that is not a nest")
	if palm == null:
		return
	assert_true(_walk_to(palm.global_position), "walked to the palm")
	_frame()
	assert_same(hud.prompt.target, palm.interactable, "the prompt is over the palm")
	_hold(INTERACT, palm.hold_s + 0.2)
	assert_eq(body.inventory.count_id(&"coco"), 1, "the climb gave a coconut")
	if not _out_of_gull_sight(body.global_position):
		assert_true(_walk_to(_safe_spot()), "walked out of the gulls' sight")
	assert_true(_out_of_gull_sight(body.global_position), "more than 8 tiles from both nests")
	var thirst: float = body.meters.thirst
	var coconut_slot: int = _slot_of(&"coco")
	_tap(StringName("slot_%d" % (coconut_slot + 1)))
	assert_eq(hud.strip.selected, coconut_slot, "the coconut's slot is selected")
	_hold(USE, 2.2)
	assert_eq(body.inventory.count_id(&"coco"), 0, "F drank the coconut")
	assert_gt(body.meters.thirst, thirst, "and it quenched thirst")
	assert_eq(body.inventory.slots[_slot_of(&"knife")].uses_left, 39, "opened with the knife")

	# The raft's inputs: every beach driftwood, the flotsam tubes and rope.
	for i: int in 2:
		_pick_up(&"inner_tube")
	_pick_up(&"rope")
	while body.inventory.count_id(&"driftwood") < RAFT_INPUTS[&"driftwood"] and not _lying(&"driftwood").is_empty():
		_pick_up(&"driftwood")
	assert_eq(body.inventory.count_id(&"driftwood"), 5, "the island's other 5 driftwood")
	# One short: a squall passes and its end puts the beach driftwood back.
	WeatherManager.sky.weather.start_weather(&"squall")
	_seconds(1.0)
	WeatherManager.sky.weather.start_weather(&"calm")
	_frame()
	_pick_up(&"driftwood")
	for item_id: StringName in RAFT_INPUTS:
		assert_eq(body.inventory.count_id(item_id), RAFT_INPUTS[item_id], "carrying the raft's %s" % item_id)

	# The raft site: E deposits everything and the player works it; then E held launches the raft.
	var raft_site := session.get_node(^"RaftSite") as BuildSite
	assert_true(_walk_to(raft_site.global_position), "walked to the raft site")
	_frame()
	assert_same(hud.prompt.target, raft_site.interactable, "the prompt is over the raft site")
	_tap(INTERACT)
	assert_true(raft_site.inputs_complete(), "E deposited the raft's inputs")
	var raft: Raft = null
	for i: int in ceili(70.0 / DT):
		raft = session.get_node_or_null(^"Raft") as Raft
		if raft != null:
			break
		_frame()
	assert_not_null(raft, "the raft is built")
	if raft == null:
		return
	_frame()
	assert_same(hud.prompt.target, raft.interactable, "the prompt is over the raft")
	_hold(INTERACT, Raft.LAUNCH_HOLD_S + 0.2)
	assert_eq(shell.crossings.size(), 1, "the raft launched")
	if shell.crossings.is_empty():
		return
	var crossing := shell.crossings[0] as Crossing
	assert_eq(crossing.rider_state(CoopSession.HOST_ID), Crossing.Rider.ABOARD, "the player is aboard")
	assert_gt(min_thirst, 0.0, "thirst never reached 0")
	assert_true(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "still offline: no port opened")
	assert_false(NetManager.is_online())
	gut.p("solo sandbar run: %d frames, %.0f s, lowest thirst %.1f" % [frames, frames * DT, min_thirst])
	# Real frames again, so the launched raft and the used-up site are freed before the shell is.
	await wait_physics_frames(2)
