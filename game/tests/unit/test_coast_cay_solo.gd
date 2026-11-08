extends GutTest
## island-generation "Handmade coast cay", crossing "Arrival" and crafting-inventory "Coast cay
## items as data", with exactly 1 player, offline: a solo player crosses, arrives alone, drinks
## from the lagoon, reads the wall, picks up the nails and builds a raft there.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SETTINGS_PATH: String = "user://test_coast_cay_settings.cfg"
const COAST: StringName = &"coast_cay"


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


# A solo run with the raft built and launched; the crossing's plan is 60 s with no beats.
func _launch() -> Array:
	var shell := _shell()
	var body := shell.session.body(1)
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0, [] as Array[RefCounted])
	return [shell, crossing]


# A solo run standing on the coast cay, with no raft behind it.
func _on_the_cay() -> GameShell:
	var shell := _shell()
	shell.travel.travel(COAST)
	return shell


func _landing_center(shell: GameShell, index: int = 0) -> Vector2:
	return IslandLayout.cell_center(shell.island.built.landing_cells()[index])


func _take(shell: GameShell, body: PlayerBody, item_id: StringName) -> int:
	var taken: int = 0
	for node: Node in shell.session.pickups.get_children():
		var item := node as WorldItem
		if item.item_id == item_id and not item.is_queued_for_deletion():
			body.global_position = item.global_position
			item.interactable.interacted.emit(body)
			taken += 1
	return taken


func test_solo_arrives_on_the_coast_cay() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	var rider := crossing.body_of(1)
	rider.meters.health = 80.0
	rider.meters.energy = 35.0
	crossing.integrity.value = 70.0
	CrossingRig.run(crossing, 60.0)
	await wait_frames(2)
	var result := shell.crossing_results[0] as CrossingResult
	assert_eq(shell.flow, GameShell.Flow.RUN, "the run goes on")
	assert_eq(shell.island.layout.id, COAST)
	var body := shell.session.body(1)
	assert_eq(body.position, _landing_center(shell), "alone, on the first landing cell")
	assert_eq(body.meters.health, 80.0)
	assert_almost_eq(body.meters.energy, float(result.riders[1]["energy"]), 0.001, "the energy the crossing left")
	assert_false(body.left_island)
	assert_true(body.visible)
	assert_eq(body.terrain, shell.island.terrain, "the body walks the cay's ground")
	var raft := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(raft, "the raft is beached")
	assert_eq(raft.integrity, 70.0)
	assert_eq(raft.position, IslandLayout.cell_center(shell.island.built.raft_site))
	assert_null(shell.session.get_node_or_null("RaftSite"), "no empty site beside it")


func test_a_broken_raft_is_lost() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	CrossingRig.run(crossing, 50.0)
	crossing.hit_vessel(500.0)
	CrossingRig.run(crossing, 10.0)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_eq(shell.island.layout.id, COAST)
	assert_eq(shell.session.body(1).position, _landing_center(shell))
	assert_null(shell.session.get_node_or_null("Raft"), "a broken raft is lost")
	assert_not_null(shell.session.get_node_or_null("RaftSite"), "the build site is empty and ready")


func test_the_beached_raft_launches_again() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var first := launched[1] as Crossing
	first.integrity.value = 70.0
	CrossingRig.run(first, 60.0)
	await wait_frames(2)
	var body := shell.session.body(1)
	var raft := shell.session.get_node("Raft") as Raft
	body.global_position = raft.global_position
	raft.interactable.interacted.emit(body)
	assert_eq(shell.crossings.size(), 1, "a second crossing starts")
	var second := shell.crossings[0] as Crossing
	assert_eq(second.integrity.value, 70.0, "at the integrity it landed with")
	second.plan = CrossingPlan.create(60.0, [] as Array[RefCounted])
	CrossingRig.run(second, 60.0)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "the coast cay names no next island")
	var rows: Array[String] = (shell.screen as SummaryScreen).rows()
	assert_string_contains(rows[0], "Balsa")


func test_a_solo_player_who_dies_in_the_crossing_does_not_arrive() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	crossing.body_of(1).meters.dead = true
	CrossingRig.run(crossing, 0.2)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	assert_eq(shell.island.layout.id, &"sandbar")


func test_solo_drinks_the_lagoon() -> void:
	var shell := _on_the_cay()
	var body := shell.session.body(1)
	var tuning := body.meters.tuning.duplicate() as SurvivalTuning
	tuning.thirst_per_s = 0.0
	body.meters.tuning = tuning
	body.meters.thirst = 50.0
	var spot := shell.session.get_node("DrinkSpot0") as DrinkSpot
	body.global_position = spot.global_position
	assert_eq(spot.hold_time_s, 2.0)
	# Hold interact for the 2 s timed interaction.
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	for i: int in 19:
		body.advance(0.1)
	assert_eq(body.meters.thirst, 50.0, "not yet at 1.9 s")
	for i: int in 3:
		body.advance(0.1)
	assert_eq(body.meters.thirst, 60.0, "thirst 60 at once")
	body.intent = MoveIntent.new()
	for i: int in 299:
		body.meters.tick(0.1, MeterContext.new())
	assert_eq(body.meters.thirst, 60.0, "still 60 at 29.9 s")
	body.meters.tick(0.1, MeterContext.new())
	assert_almost_eq(body.meters.thirst, 55.0, 0.001, "55 after 30 more seconds")
	assert_false(body.meters.dead, "a brackish drink never revives or kills")


func test_the_lagoon_never_runs_dry() -> void:
	var shell := _on_the_cay()
	var body := shell.session.body(1)
	body.meters.thirst = 10.0
	var spot := shell.session.get_node("DrinkSpot0") as DrinkSpot
	for i: int in 5:
		spot.use(body)
	assert_eq(body.meters.thirst, 60.0, "every drink counts, however many")


func test_solo_reads_the_wall() -> void:
	var shell := _on_the_cay()
	var body := shell.session.body(1)
	var slogan: IslandSign = null
	for node: Node in shell.session.get_children():
		var sign_node := node as IslandSign
		if sign_node != null and sign_node.line_es.begins_with("«AQUÍ NO SE RINDE"):
			slogan = sign_node
	assert_not_null(slogan, "the slogan is on the wall")
	var inventory_before: Array = body.inventory.to_net()
	var health_before: float = body.meters.health
	var thirst_before: float = body.meters.thirst
	body.global_position = slogan.global_position
	slogan.use(body)
	var bubble := slogan.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)) as SpeechBubble
	assert_not_null(bubble, "a speech bubble over the sign")
	assert_eq(bubble.text, slogan.line_es, "the Spanish line")
	assert_eq(body.inventory.to_net(), inventory_before)
	assert_eq(body.meters.health, health_before)
	assert_eq(body.meters.thirst, thirst_before)


func test_solo_takes_the_post_nails_and_builds_a_raft() -> void:
	var shell := _on_the_cay()
	var body := shell.session.body(1)
	assert_gt(_take(shell, body, &"nails"), 0)
	_take(shell, body, &"mirror")
	assert_eq(body.inventory.count_id(&"nails"), 4, "the post's nails")
	assert_eq(body.inventory.count_id(&"mirror"), 1)
	_take(shell, body, &"inner_tube")
	_take(shell, body, &"driftwood")
	_take(shell, body, &"rope")
	assert_eq(body.inventory.count_id(&"inner_tube"), 2)
	assert_gte(body.inventory.count_id(&"driftwood"), 6)
	assert_eq(body.inventory.count_id(&"rope"), 4, "the buried cache's rope")
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	site.deposit(body)
	site.work(1.0)
	var raft := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(raft, "one player built a raft alone")
	assert_eq(raft.integrity, 100.0)


func test_coast_cay_creatures_for_a_solo_arrival() -> void:
	var shell := _on_the_cay()
	await wait_frames(3)
	var spawner := shell.session.get_node("Creatures") as CreatureSpawner
	var sharks: Array[Creature] = spawner.creatures(&"reef_shark")
	assert_eq(sharks.size(), 1, "one reef shark offshore")
	if not sharks.is_empty():
		var cell: Vector2i = CreatureNav.cell_of(sharks[0].position)
		assert_eq(shell.island.terrain.terrain_at(cell), DataEnums.Terrain.DEEP)
		assert_gte(spawner.nav.land_distance(cell), 2, "at least 2 tiles from shore")
	assert_eq(spawner.creatures(&"seagull").size(), 0, "no palm on the cay is a nest")
	assert_eq(spawner.creatures(&"land_crab").size(), 0, "crabs come out at night")
	spawner.apply_phase(DataEnums.DayPhase.NIGHT)
	var crabs: Array[Creature] = spawner.creatures(&"land_crab")
	assert_gt(crabs.size(), 0, "crabs on its beaches at night")
	for crab: Creature in crabs:
		assert_eq(shell.island.terrain.terrain_at(CreatureNav.cell_of(crab.position)), DataEnums.Terrain.BEACH)


func test_solo_uses_aloe_on_sunburn_and_bleeding() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.meters.set_status(DataEnums.Status.SUNBURN, true)
	body.meters.set_status(DataEnums.Status.BLEEDING, true)
	body.inventory.add(&"aloe", 1)
	var aloe := GameState.content.get_entry(&"items", &"aloe") as ItemData
	assert_eq(aloe.uses[0].time_s, 1.0, "a 1 s use")
	assert_true(ItemUser.use(body, 0, 0))
	assert_false(body.meters.has_status(DataEnums.Status.SUNBURN))
	assert_false(body.meters.has_status(DataEnums.Status.BLEEDING))
	assert_eq(body.inventory.count_id(&"aloe"), 0, "the leaf is used up")


func test_solo_lights_a_fire_with_the_lighter_in_one_second() -> void:
	var arena := Node2D.new()
	add_child_autofree(arena)
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.inventory.add(&"lighter", 1)
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	var recipe := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	var site := body.crafter.place_site(recipe, Vector2(8, 0), arena)
	site.deposit(body)
	assert_true(body.crafter.start_work(site))
	body.crafter.advance(0.9)
	assert_eq(get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP).size(), 0, "no fire at 0.9 s")
	body.crafter.advance(0.1)
	assert_eq(get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP).size(), 1, "the fire burns after 1 s")
	assert_eq(body.inventory.slots[0].uses_left, 19, "the lighter has 19 uses left")
