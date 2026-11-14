extends GutTest
## coop-networking "Structure state on every peer" and "Structure messages come only from the host"
## (structure-state-sync), offline: a fire's `lit` takes effect wherever it is set, so a value the
## host's synchronizer writes gives a client's copy the same lit fire, lit-fires membership and use;
## one player on the real sandbar climbs a palm, fills and empties a catcher and puts a fire out with
## no structure message sent; and a client's palm sync holds counts to the layout's.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
## The sandbar's first palm holds 2 of its 10 coconuts (they go round its 6 palms in reading order).
const PALM: int = 0
## Inside the cell south of the bench, within its reach.
const AT_BENCH: Vector2 = Vector2(0.0, 10.0)


# --- a fire's lit, set from outside ------------------------------------------------------------------------

func test_setting_lit_after_ready_moves_the_fire_in_and_out_of_the_lit_fires_with_no_morale() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	var fire := FIRE_SCENE.instantiate() as Fire
	add_child_autofree(fire)
	body.meters.morale = 50.0
	assert_false(fire.is_in_group(PlayerBody.FIRE_GROUP), "a new fire is out")
	assert_false(fire.interactable.enabled)
	fire.lit = true
	assert_true(fire.is_in_group(PlayerBody.FIRE_GROUP), "lit: one of the lit fires")
	assert_true(fire.interactable.enabled, "lit: it can be put out")
	fire.lit = false
	assert_false(fire.is_in_group(PlayerBody.FIRE_GROUP), "out: not a lit fire")
	assert_false(fire.interactable.enabled, "out: nothing to put out")
	fire.lit = true
	assert_true(fire.is_in_group(PlayerBody.FIRE_GROUP), "lit again")
	assert_almost_eq(body.meters.morale, 50.0, 0.001, "setting lit is no fire-lit morale event")


func test_setting_lit_before_ready_takes_effect_when_it_enters_the_tree() -> void:
	var lit_fire := FIRE_SCENE.instantiate() as Fire
	lit_fire.lit = true
	add_child_autofree(lit_fire)
	assert_true(lit_fire.is_in_group(PlayerBody.FIRE_GROUP), "lit before ready: a lit fire")
	assert_true(lit_fire.interactable.enabled)
	assert_gt(lit_fire.burn_left_s, 0.0, "and it burns")
	var out_fire := FIRE_SCENE.instantiate() as Fire
	out_fire.lit = true
	out_fire.lit = false
	add_child_autofree(out_fire)
	assert_false(out_fire.is_in_group(PlayerBody.FIRE_GROUP), "out before ready: not a lit fire")
	assert_false(out_fire.interactable.enabled)


# --- one player, offline, on the real sandbar ----------------------------------------------------------------

# A solo run on the sandbar without creatures: the island, a started session and its one player.
func _solo() -> Dictionary:
	NetManager.start_solo()
	WeatherManager.stop()
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	var player := session.body(CoopSession.HOST_ID)
	player.player_input.enabled = false
	return {"island": island, "session": session, "player": player}


func _end_solo() -> void:
	WeatherManager.stop()
	NetManager.leave()


# The solo player builds `recipe_id` at the hut's bench and returns the structure it became.
func _build(session: CoopSession, player: PlayerBody, recipe_id: StringName, inputs: Dictionary) -> Node:
	var bench := session.get_node(NodePath(SandbarIsland.BENCH_NAME)) as Workbench
	player.global_position = bench.global_position + AT_BENCH
	assert_true(session.craft_for(CoopSession.HOST_ID, recipe_id, session.get_path_to(bench)), "a %s site" % recipe_id)
	var site: BuildSite = null
	for node: Node in session.entities.get_children():
		if node is BuildSite and (node as BuildSite).recipe.id == recipe_id and not node.is_queued_for_deletion():
			site = node
	for id: StringName in inputs:
		player.inventory.add(id, inputs[id])
	site.deposit(player)
	site.work(1.0)
	for node: Node in session.entities.get_children():
		var recipe: Variant = node.get_meta(SitePlacer.RECIPE_META, &"")
		if recipe == recipe_id and not node is BuildSite and not node.is_queued_for_deletion():
			return node
	return null


func test_a_solo_players_palm_catcher_and_fire_change_on_their_own_and_nothing_is_sent() -> void:
	var run := _solo()
	var island := run["island"] as SandbarIsland
	var session := run["session"] as CoopSession
	var player := run["player"] as PlayerBody
	var palm := island.palms[PALM]
	assert_eq(palm.coconuts, 2, "the first palm holds 2")
	palm.interactable.use(player)
	assert_eq(palm.coconuts, 1, "climbed: 1 left")
	assert_eq(player.inventory.count_id(Palm.COCONUT_ID), 1, "and the player has the coconut")
	var catcher := _build(session, player, &"rain_catcher", {&"driftwood": 4, &"tarp": 1}) as RainCatcher
	assert_not_null(catcher, "the player built a rain catcher")
	catcher.climate.weather_id = &"squall"
	catcher.advance(catcher.tuning.rain_fill_s)
	catcher.climate.weather_id = &"calm"
	assert_eq(catcher.cups, 1, "the squall filled it")
	catcher.interactable.use(player)
	assert_eq(player.inventory.count_id(&"rain_cup"), 1, "the player took the cup")
	assert_eq(catcher.cups, 0, "and the catcher holds none")
	var fire := _build(session, player, &"fire", {&"driftwood": 3, &"dry_grass": 1}) as Fire
	assert_not_null(fire, "the player built a fire")
	assert_true(fire.lit, "lit")
	fire.interactable.use(player)
	assert_false(fire.lit, "put out")
	assert_false(fire.is_in_group(PlayerBody.FIRE_GROUP), "no longer a lit fire")
	await wait_physics_frames(5)
	var sync := session.get_node(NodePath(SandbarIsland.PALM_SYNC_NAME)) as PalmSync
	assert_not_null(sync, "the island added its palm sync, solo too")
	assert_eq(sync.sent_count, 0, "and it sent no structure message")
	_end_solo()


# --- what a client's palm sync applies --------------------------------------------------------------

func test_a_palm_count_is_held_between_0_and_the_layouts() -> void:
	var run := _solo()
	var island := run["island"] as SandbarIsland
	var sync := (run["session"] as CoopSession).get_node(NodePath(SandbarIsland.PALM_SYNC_NAME)) as PalmSync
	var palm := island.palms[PALM]
	sync.apply_count(PALM, 9)
	assert_eq(palm.coconuts, 2, "more than its layout's 2 shows 2")
	sync.apply_count(PALM, -1)
	assert_eq(palm.coconuts, 0, "below 0 shows 0")
	sync.apply_count(island.palms.size(), 0)
	sync.apply_count(-1, 0)
	var before: Array[int] = []
	for each: Palm in island.palms:
		before.append(each.coconuts)
	sync.apply_counts(PackedInt32Array([0, 0]))
	var after: Array[int] = []
	for each: Palm in island.palms:
		after.append(each.coconuts)
	assert_eq(after, before, "an index out of range or a list for another island changes nothing")
	var all_zero := PackedInt32Array()
	all_zero.resize(island.palms.size())
	sync.apply_counts(all_zero)
	assert_eq(island.palms[1].coconuts, 0, "a list of the right size is applied")
	_end_solo()
