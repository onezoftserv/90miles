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


# A solo run standing on the coast cay, with no raft behind it. The old island is freed by the
# time this returns.
func _on_the_cay() -> GameShell:
	var shell := _shell()
	shell.travel.travel(COAST)
	await wait_process_frames(2)
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
	var shell := await _on_the_cay()
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
	var shell := await _on_the_cay()
	var body := shell.session.body(1)
	body.meters.thirst = 10.0
	var spot := shell.session.get_node("DrinkSpot0") as DrinkSpot
	for i: int in 5:
		spot.use(body)
	assert_eq(body.meters.thirst, 60.0, "every drink counts, however many")


# --- the sign note (sign-note-panel), exactly 1 player, offline ---------------------------------------
# The body, the prompt and the note are stepped by hand from the real input state, with no frame awaited
# after the run is set up.

func _release_keys() -> void:
	for keycode: Key in [KEY_E, KEY_ESCAPE, KEY_F]:
		_key(keycode, false)
	get_tree().paused = false


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# One frame: the intent from the input, the body (the host's interaction), the prompt, the note.
func _frame(shell: GameShell) -> void:
	var body := shell.session.body(1)
	body.intent = body.player_input.build_intent()
	body.advance(0.1)
	shell.hud.prompt.tick(0.1)
	shell.hud.sign_note._process(0.1)


func _tap(shell: GameShell, keycode: Key) -> void:
	_key(keycode, true)
	_frame(shell)
	_key(keycode, false)
	_frame(shell)


func _sign_with(shell: GameShell, prefix: String) -> IslandSign:
	for node: Node in shell.session.get_children():
		var sign_node := node as IslandSign
		if sign_node != null and sign_node.line_es.begins_with(prefix):
			return sign_node
	return null


# A solo player beside the dead radio with its note open, in Spanish.
func _reading(shell: GameShell) -> IslandSign:
	var radio := _sign_with(shell, "Un radio ruso")
	assert_not_null(radio, "the radio is on the cay")
	var body := shell.session.body(1)
	body.global_position = radio.global_position + Vector2(0.0, 8.0)
	_frame(shell)
	assert_same(shell.hud.prompt.target, radio, "the radio is the candidate")
	_tap(shell, KEY_E)
	return radio


func test_solo_reads_the_radio_in_a_note_and_walks_away() -> void:
	var shell := await _on_the_cay()
	var body := shell.session.body(1)
	var inventory_before: Array = body.inventory.to_net()
	var health_before: float = body.meters.health
	var radio := _reading(shell)
	var note := shell.hud.sign_note
	assert_true(note.is_open(), "E opens the note")
	assert_eq(note.text_shown(), radio.line_es, "the Spanish line")
	assert_eq(note.close_text(), "[E] Cerrar")
	assert_false(get_tree().paused, "the clock keeps running")
	assert_true(shell.session.can_process())
	assert_true(body.hud_holds_interact)
	assert_null(radio.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)), "no speech bubble over the sign")
	assert_eq(body.inventory.to_net(), inventory_before)
	assert_eq(body.meters.health, health_before)
	body.global_position = radio.global_position + Vector2(0.0, 32.0)
	_frame(shell)
	assert_false(note.is_open(), "2 tiles away closes it")
	_release_keys()


func test_e_again_closes_the_note_and_picks_nothing_up() -> void:
	var shell := await _on_the_cay()
	var body := shell.session.body(1)
	var radio := _reading(shell)
	var drop := shell.session.spawn_pickup(&"driftwood", 1, body.global_position + Vector2(6.0, 0.0))
	var inventory_before: Array = body.inventory.to_net()
	_tap(shell, KEY_E)
	assert_false(shell.hud.sign_note.is_open(), "E closes the note")
	assert_eq(body.inventory.to_net(), inventory_before, "nothing is picked up")
	assert_true(is_instance_valid(drop) and drop.interactable.enabled, "the pickup beside it stays on the ground")
	assert_false(body.hud_holds_interact, "released, interact is the player's again")
	assert_not_null(radio)
	_release_keys()


func test_esc_closes_the_note_without_pausing_and_a_second_esc_pauses() -> void:
	var shell := await _on_the_cay()
	_reading(shell)
	_tap(shell, KEY_ESCAPE)
	assert_false(shell.hud.sign_note.is_open(), "the first Esc closes the note")
	assert_false(get_tree().paused, "and does not pause")
	assert_false(shell.hud.pause_menu.visible)
	_tap(shell, KEY_ESCAPE)
	assert_true(shell.hud.pause_menu.visible, "the second opens the pause menu")
	assert_true(get_tree().paused)
	_release_keys()


func test_f_with_a_rain_cup_uses_nothing_while_the_note_is_open() -> void:
	var shell := await _on_the_cay()
	var body := shell.session.body(1)
	body.inventory.add(&"rain_cup", 1)
	body.meters.thirst = 50.0
	shell.hud.strip.select(0)
	_reading(shell)
	assert_true(shell.hud.sign_note.is_open())
	_key(KEY_F, true)
	for i: int in 10:
		_frame(shell)
		shell.hud.strip._process(0.1)
	assert_true(shell.hud.sign_note.is_open(), "the note stays open")
	assert_eq(body.inventory.count_id(&"rain_cup"), 1, "nothing is used")
	assert_true(body.meters.thirst <= 50.0, "no drink")
	_release_keys()


func test_going_down_closes_the_note() -> void:
	var shell := await _on_the_cay()
	var body := shell.session.body(1)
	_reading(shell)
	body.set_downed(true)
	_frame(shell)
	assert_false(shell.hud.sign_note.is_open())
	body.set_downed(false)
	_release_keys()


# art-pass-followups: a sign's prompt has its verb, "[E] Mirar" (Spanish) and "[E] Look".
func test_a_signs_prompt_reads_mirar() -> void:
	var shell := await _on_the_cay()
	var body := shell.session.body(1)
	var found: Array[IslandSign] = []
	for node: Node in shell.session.get_children():
		if node is IslandSign:
			found.append(node as IslandSign)
	assert_false(found.is_empty(), "the cay has signs")
	var words := HudText.load_default()
	for sign_node: IslandSign in found:
		assert_eq(InteractPrompt.head_parts(sign_node, body, "E", words, "es"), PackedStringArray(["[E] Mirar", ""]), String(sign_node.name))
		assert_eq(InteractPrompt.head_parts(sign_node, body, "E", words, "en"), PackedStringArray(["[E] Look", ""]), String(sign_node.name))


func test_solo_takes_the_post_nails_and_builds_a_raft() -> void:
	var shell := await _on_the_cay()
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
	var shell := await _on_the_cay()
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


# Two bodies in one offline session (no network): the rider is held, the other is on the island.
func test_a_waiting_rider_is_no_teammate_for_the_last_player() -> void:
	var session := CrossingRig.make_session(self, 2)
	var rider := session.body(1)
	var last := session.body(2)
	assert_true(last._has_living_teammate(INF), "two players on the island: a teammate could revive")
	IslandArrival.hold(rider)
	assert_false(last._has_living_teammate(INF), "a rider waiting out of play is no teammate")
	assert_false(last._has_living_teammate(80.0), "and no company either")
	IslandArrival.land(rider, last.position, last.terrain)
	assert_true(last._has_living_teammate(INF), "back in play, they are one again")


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
