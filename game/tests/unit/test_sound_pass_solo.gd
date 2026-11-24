extends GutTest
## sound-pass end to end with exactly 1 player, offline (audio "Pick-up cue", "Low-thirst cue",
## "Compass rattle cue", "Ambience follows place, time and weather", "Thunder", "Raft hit and
## arrival", "The patrol motor swells over the horizon warning", "Loudhailer", "Loops end with the
## run"): a solo run started from the shell, as a player starts it, with the RunSounds the shell
## attaches. The clock is stopped and stepped by hand, and the checks read what AudioManager was
## asked for (sfx_played, loop targets), never an audio device. AudioManager's repeat guard reads the
## wall clock, so a test that plays one id twice forgets the guard in between.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
## Seconds since dawn at night (as test_art_sim_invariance starts its night runs).
const NIGHT_S: float = 430.0

var settings_path: String = UserTmp.path("test_sound_pass_solo.cfg")
var shell: GameShell
var sounds: RunSounds
var body: PlayerBody
var bank: SoundBank
var played: Array[StringName] = []


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	AudioManager.stop_loops()
	AudioManager.reset_guard()
	played.clear()
	AudioManager.sfx_played.connect(_on_played)
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	# The run's clock is stepped by hand from here on, with no weather rolls.
	WeatherManager.stop()
	body = shell.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	sounds = shell.hud.get_node_or_null(^"RunSounds") as RunSounds
	bank = load(SoundBank.STANDARD_PATH) as SoundBank


func after_each() -> void:
	if AudioManager.sfx_played.is_connected(_on_played):
		AudioManager.sfx_played.disconnect(_on_played)
	AudioManager.stop_loops()
	AudioManager.set_volume(1.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _on_played(id: StringName) -> void:
	played.append(id)


func _count(id: StringName) -> int:
	return played.count(id)


func _boat() -> Creature:
	for node: Node in shell.session.entities.get_children():
		var creature := node as Creature
		if creature != null and creature.is_patrol():
			return creature
	return null


func _clock(boat: Creature, at_s: float) -> void:
	(boat.brain as PatrolRoute).set_clock(at_s)
	boat.advance(0.0)
	sounds.step(0.0)


func test_a_solo_run_has_one_run_sounds_and_hears_the_sea() -> void:
	assert_eq(shell.session.peer_ids().size(), 1, "one offline player")
	assert_not_null(sounds, "the shell attaches RunSounds to the HUD")
	assert_eq(sounds.local_peer, CoopSession.HOST_ID)
	assert_eq(AudioManager.loop_target(&"sea"), bank.sea_island, "the sea on the island")
	assert_eq(AudioManager.loop_target(&"wind"), 0.0)
	assert_eq(AudioManager.loop_target(&"night"), 0.0, "it is day")
	assert_true(AudioManager.loop_playing(&"sea"))


func test_solo_pick_up_plays_once_and_using_plays_nothing() -> void:
	var item: WorldItem = null
	for node: Node in shell.session.pickups.get_children():
		item = node as WorldItem
		if item != null:
			break
	assert_not_null(item, "the sandbar has pick-ups")
	item.interactable.interacted.emit(body)
	assert_eq(_count(&"pickup"), 1, "picking it up plays pickup")
	var taken: StringName = body.inventory.slots[0].item_id
	AudioManager.reset_guard()
	body.inventory.remove_id(taken, 1)
	assert_eq(_count(&"pickup"), 1, "taking it out plays nothing")


func test_solo_crab_pinch_plays_the_hit_through_the_meters() -> void:
	# The meters' first look is a baseline (damage-feedback), so they look once before the pinch.
	shell.hud.meters.step(1.0 / 60.0)
	CreatureWorld.new().pinch(body, GameState.content.get_entry(&"creatures", &"land_crab") as CreatureData)
	shell.hud.meters.step(1.0 / 60.0)
	assert_eq(_count(&"hurt_hit"), 1)


func test_solo_low_thirst_warns_once_and_again_after_a_drink() -> void:
	body.meters.thirst = 26.0
	sounds.step(0.0)
	body.meters.thirst = 25.0
	sounds.step(0.0)
	body.meters.thirst = 10.0
	sounds.step(0.0)
	assert_eq(_count(&"thirst_low"), 1, "once on the fall to 25")
	body.meters.thirst = 40.0
	sounds.step(0.0)
	AudioManager.reset_guard()
	body.meters.thirst = 25.0
	sounds.step(0.0)
	assert_eq(_count(&"thirst_low"), 2, "again after a coconut to 40")


func test_solo_compass_needle_rattles() -> void:
	shell.hud.needle.rattled.emit()
	assert_eq(_count(&"compass_rattle"), 1)


func test_solo_night_raises_the_night_loop() -> void:
	WeatherManager.sky.start_at(NIGHT_S)
	assert_eq(WeatherManager.phase(), DataEnums.DayPhase.NIGHT)
	sounds.step(0.0)
	assert_eq(AudioManager.loop_target(&"night"), bank.night_level)
	assert_eq(AudioManager.loop_target(&"sea"), bank.sea_island, "the sea keeps playing")


func test_solo_squall_thunders_far_then_near_then_rolls_and_raises_the_wind() -> void:
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"squall", 30.0)
	sounds.step(0.0)
	assert_eq(_count(&"thunder"), 1, "the warning thunders")
	var thunder: SoundData = bank.entry(&"thunder")
	assert_almost_eq(AudioManager.last_voice().volume_db, thunder.volume_db + bank.thunder_far_db, 0.001, "far off")
	AudioManager.reset_guard()
	WeatherManager.sky.weather.apply(&"squall", 60.0, &"", -1.0)
	sounds.step(0.0)
	assert_eq(_count(&"thunder"), 2, "the break thunders")
	assert_almost_eq(AudioManager.last_voice().volume_db, thunder.volume_db, 0.001, "close")
	assert_eq(AudioManager.loop_target(&"wind"), bank.wind_squall)
	AudioManager.reset_guard()
	sounds.step(bank.thunder_gap_max_s + 0.1)
	assert_eq(_count(&"thunder"), 3, "it rolls again while the squall blows")
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	sounds.step(0.0)
	assert_eq(AudioManager.loop_target(&"wind"), 0.0, "the wind drops with the squall")


func test_solo_patrol_warning_swells_and_the_loudhailer_calls() -> void:
	await wait_frames(2)
	WeatherManager.stop()
	var boat := _boat()
	assert_not_null(boat, "the sandbar has its patrol boat")
	if boat == null:
		return
	var warning_s: float = boat.data.patrol.horizon_warning_s
	assert_eq(warning_s, 20.0, "the coast patrol warns for 20 s")
	_clock(boat, 5.0)
	assert_eq(boat.state_id, PatrolRoute.State.HORIZON)
	var at_5: float = AudioManager.loop_target(&"patrol_motor")
	_clock(boat, 15.0)
	var at_15: float = AudioManager.loop_target(&"patrol_motor")
	assert_gt(at_5, 0.0, "the motor is heard at 5 s")
	assert_gt(at_15, at_5, "louder at 15 s than at 5 s")
	_clock(boat, warning_s - 0.001)
	assert_almost_eq(AudioManager.loop_target(&"patrol_motor"), db_to_linear(bank.motor_high_db), 0.01, "high as the warning ends")
	_clock(boat, warning_s + 5.0)
	assert_eq(boat.state_id, PatrolRoute.State.LAP)
	(boat.brain as PatrolRoute).spot(body, &"sight")
	sounds.step(0.0)
	assert_eq(_count(&"loudhailer"), 1, "the alert's call")


func test_solo_crossing_raises_sea_and_wind_hits_and_arrives() -> void:
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0, [])
	sounds.step(0.0)
	assert_eq(sounds.riding(), crossing)
	assert_eq(AudioManager.loop_target(&"sea"), bank.sea_crossing, "louder at sea")
	assert_eq(AudioManager.loop_target(&"wind"), bank.wind_crossing)
	crossing.hit_vessel(10.0)
	sounds.step(0.0)
	assert_eq(_count(&"raft_hit"), 1)
	sounds.step(0.0)
	assert_eq(_count(&"raft_hit"), 1, "one hit, one sound")
	# The raft's materials going into the bag above were real gains: count from here on.
	var pickups_before: int = _count(&"pickup")
	CrossingRig.run(crossing, 60.0)
	assert_true(crossing.finished)
	assert_eq(_count(&"arrival"), 1, "alive at the end")
	# Landing on the coast cay over the next frames: a new island under the same RunSounds.
	await wait_frames(3)
	WeatherManager.stop()
	sounds.step(0.0)
	assert_null(sounds.riding(), "ashore")
	assert_eq(AudioManager.loop_target(&"sea"), bank.sea_island, "the sea back to its island level")
	assert_eq(AudioManager.loop_target(&"wind"), 0.0, "no wind ashore on a calm day")
	assert_eq(_count(&"pickup"), pickups_before, "landing with the bag is not a pick-up")
	assert_eq(_count(&"thirst_low"), 0)
	assert_eq(_count(&"raft_hit"), 1, "no more hits once the crossing is over")
	assert_eq(_count(&"arrival"), 1)


func test_solo_death_stops_every_loop() -> void:
	WeatherManager.sky.start_at(NIGHT_S)
	sounds.step(0.0)
	AudioManager.step_loops(5.0)
	assert_true(AudioManager.loop_playing(&"sea"))
	assert_true(AudioManager.loop_playing(&"night"))
	body.meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	# The summary queues the HUD (and its RunSounds) for freeing at the end of this frame.
	await wait_frames(1)
	assert_null(shell.hud)
	assert_eq(AudioManager.playing_loops(), [] as Array[StringName], "nothing plays over the summary")


func test_quitting_the_run_to_the_title_stops_every_loop() -> void:
	sounds.step(0.0)
	AudioManager.step_loops(5.0)
	assert_true(AudioManager.loop_playing(&"sea"))
	shell.back_to_title()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_eq(AudioManager.playing_loops(), [] as Array[StringName], "abandoning the run frees the HUD and its sounds at once")
