extends GutTest
## guardacostas-capture, group 12 (design.md §14, spec "Capture cues"), solo and host plus client: the
## rope mark over a captive on both peers (gone once freed), the "[E] Soltar" prompt hidden while a
## soldier is within 3 tiles of the captive, the squad's landing, spot and leaving calls in formal
## Spanish over a soldier, the open eye filling under a soldier's sight, and the soldier and dinghy
## drawn from the synced state.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SETTINGS_PATH: String = "user://test_capture_cues_settings.cfg"
const TIMEOUT_S: float = 6.0
const TILE: float = 16.0

var net: NetHarness = null
var huds: Array[RunHud] = []
var patrol: PatrolData


func before_each() -> void:
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for hud: RunHud in huds:
		if is_instance_valid(hud):
			hud.queue_free()
	huds.clear()
	if net != null:
		net.teardown()
		net = null
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)


func _hud(session: CoopSession, peer: int) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, peer, false)
	return hud


func _pair() -> Array[CoopSession]:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


# --- the rope mark ----------------------------------------------------------------------------------

# Spec "The rope mark".
func test_both_peers_show_the_rope_mark_over_a_captive_and_neither_once_freed() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	var host_hud := _hud(host, CoopSession.HOST_ID)
	var client_hud := _hud(client, id)
	CaptureRules.capture(host.body(id), host.body(CoopSession.HOST_ID), patrol)
	var roped := func() -> bool:
		host_hud.marks.tick()
		client_hud.marks.tick()
		return host_hud.marks.has_rope(host.body(id)) and client_hud.marks.has_rope(client.body(id))
	assert_true(await wait_until(roped, TIMEOUT_S), "the rope mark over the captive on both peers")
	assert_eq(host_hud.marks.rope_rect(host.body(id)).size, BodyMarks.MARK_SIZE, "7×5")
	CaptureRules.release(host.body(id))
	var gone := func() -> bool:
		host_hud.marks.tick()
		client_hud.marks.tick()
		return not host_hud.marks.has_rope(host.body(id)) and not client_hud.marks.has_rope(client.body(id))
	assert_true(await wait_until(gone, TIMEOUT_S), "gone on both peers once freed")


# --- the prompt -------------------------------------------------------------------------------------

# Spec "No prompt while a guard is near": a free player 1 tile from a captive, a soldier 2 tiles from
# the captive; the prompt shows only once the soldier is 4 tiles away.
func test_the_soltar_prompt_shows_only_while_no_soldier_is_within_3_tiles() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	var hud := _hud(host, CoopSession.HOST_ID)
	var captive := host.body(id)
	CaptureRules.capture(captive, host.body(CoopSession.HOST_ID), patrol)
	captive.seat_captive(captive.global_position)
	host.body(CoopSession.HOST_ID).global_position = captive.global_position + Vector2(TILE * 0.8, 0.0)
	var soldier := Creature.make(GameState.content.get_entry(&"creatures", &"shore_soldier") as CreatureData)
	host.entities.add_child(soldier)
	soldier.position = captive.global_position + Vector2(-2.0 * TILE, 0.0)
	captive.free_handle.refresh()
	hud.prompt.tick(0.0)
	assert_false(captive.free_handle.enabled, "a guard within 3 tiles")
	assert_ne(hud.prompt.target, captive.free_handle, "no prompt while the guard is near")
	soldier.position = captive.global_position + Vector2(-4.0 * TILE, 0.0)
	captive.free_handle.refresh()
	hud.prompt.tick(0.0)
	assert_true(captive.free_handle.enabled)
	assert_eq(hud.prompt.target, captive.free_handle, "the prompt appears only then")
	var head: String = InteractPrompt.head_text(captive.free_handle, host.body(CoopSession.HOST_ID), "E", hud.prompt.text, "es")
	assert_true(head.contains("Soltar"), "[E] Soltar: %s" % head)
	assert_almost_eq(captive.free_handle.hold_time_s, 1.0, 0.000001, "a 1 s ring")


# --- the calls, the eye, the looks (solo) -------------------------------------------------------------

func _solo() -> GameShell:
	NetManager.start_solo()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


# The solo run's boat, docked by a spot on land, with its squad ashore.
func _land_squad(shell: GameShell) -> Creature:
	var spawner := shell.session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	var brain := boat.brain as PatrolRoute
	brain.set_clock(patrol.horizon_warning_s + 10.0)
	boat.advance(0.0)
	var body := shell.session.body(1)
	brain.spot(body, &"sight")
	body.global_position = Vector2(2.5, 2.5) * TILE
	body.stealth_state = MovementStep.Stealth.SUBMERGED
	for i: int in 100:
		if boat.squad_state == PatrolRoute.Squad.ASHORE:
			break
		boat.advance(0.1)
	return boat


# Spec "A solo player hears the landing", and the spot and leaving calls.
func test_a_solo_player_sees_the_squads_landing_spot_and_leaving_calls_in_formal_spanish() -> void:
	var shell := _solo()
	await wait_physics_frames(2)
	var boat := _land_squad(shell)
	var look := boat.get_node(^"SquadLook") as SquadLook
	look.step(0.0)
	assert_eq(look.calls_shown, 1, "the landing call")
	assert_true(patrol.squad_land_lines_es.has(look.last_call), look.last_call)
	assert_true(look.last_caller is Creature and (look.last_caller as Creature).data.id == &"shore_soldier", "over a soldier")
	var bubble := look.last_caller.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)) as SpeechBubble
	assert_not_null(bubble)
	assert_eq(bubble.text, look.last_call)
	var brain := boat.brain as PatrolRoute
	var soldier: Creature = brain.soldiers[0]
	(soldier.brain as SearchCapture).spot(soldier, shell.session.body(1))
	look.step(0.0)
	assert_eq(look.calls_shown, 2, "the spot call")
	assert_true(patrol.squad_spot_lines_es.has(look.last_call))
	assert_eq(look.last_caller, soldier, "over the soldier giving chase")
	brain.plan.elapsed_s = patrol.search_duration_s
	boat.advance(0.1)
	look.step(0.0)
	assert_eq(look.calls_shown, 3, "the leaving call")
	assert_true(patrol.squad_leave_lines_es.has(look.last_call))
	for line: String in patrol.squad_land_lines_es + patrol.squad_spot_lines_es + patrol.squad_leave_lines_es:
		assert_false(line.contains("pa'") or line.contains("'tá"), "formal: %s" % line)


func test_the_open_eye_fills_under_a_soldiers_sight() -> void:
	var shell := _solo()
	await wait_physics_frames(2)
	var boat := _land_squad(shell)
	var body := shell.session.body(1)
	var soldier: Creature = (boat.brain as PatrolRoute).soldiers[0]
	body.stealth_state = MovementStep.Stealth.VISIBLE
	body.global_position = soldier.position + soldier.facing.normalized() * 3.0 * TILE
	var spawner := shell.session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.watch.step(1.0)
	body.spot_shown = body.spot_fraction()
	shell.hud.marks.tick()
	assert_gt(body.spot_shown, 0.0, "the soldier's sight fills the meter")
	assert_true(shell.hud.marks.has_open_eye(body), "the open eye over the player")
	assert_almost_eq(shell.hud.marks.eye_fill(body), 0.5, 0.01, "half full after 1 s of 2")


func test_the_soldier_and_the_dinghy_are_drawn_from_the_synced_state() -> void:
	var shell := _solo()
	await wait_physics_frames(2)
	var boat := _land_squad(shell)
	var look := boat.get_node(^"SquadLook") as SquadLook
	look.step(0.0)
	assert_true(look.dinghy_visible, "the dinghy on the beach")
	assert_eq(look.dinghy_px, IslandLayout.cell_center(boat.landing))
	var soldier: Creature = (boat.brain as PatrolRoute).soldiers[0]
	var soldier_look := soldier.get_node(^"SquadLook") as SquadLook
	soldier_look.step(0.0)
	assert_false(soldier_look.dinghy_visible, "a soldier has no dinghy")
	assert_true(soldier.is_in_group(FreeHandle.SOLDIER_GROUP))
