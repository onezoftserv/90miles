extends GutTest
## island-stop, inventory-hud "The raft's prompt shows its state", "Raft work list" and "Raft jobs in
## the prompt", with exactly 1 player, offline, on the coast cay with a raft beached at 48: the
## launch prompt adds the state and the warning and still launches on a 1 s hold; E at the work
## point opens the raft's list with its state as the head line and the mend as a row, refused with
## its reason on a whole raft; choosing it opens the job, whose prompt names it and lists what is
## missing. The body, the prompt and the list are stepped by hand from the real input state.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const STEP_S: float = 0.1
const WARNING: String = "Así no llegas ni a la esquina."
const SENT: String = "craft_sent"

var island: SandbarIsland
var session: CoopSession
var hud: RunHud
var body: PlayerBody
var raft: Raft


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = COAST_CAY
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	island.beach_raft(48.0)
	raft = session.get_node("Raft") as Raft
	body = session.body(1)
	body.player_input.enabled = false
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, true)
	watch_signals(hud.craft_list)


func after_each() -> void:
	_key(KEY_E, false)
	WeatherManager.stop()
	NetManager.leave()


func _frame() -> void:
	body.intent = body.player_input.build_intent()
	body.advance(STEP_S)
	hud.prompt.tick(STEP_S)
	hud.craft_list._process(STEP_S)


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(keycode: Key) -> void:
	_key(keycode, true)
	_frame()
	_key(keycode, false)
	_frame()


func _at_work_point() -> void:
	body.global_position = raft.work_point.global_position
	_frame()


func _open_list() -> void:
	_at_work_point()
	assert_same(hud.prompt.target, raft.work_point, "the work point is the candidate")
	_tap(KEY_E)
	assert_true(hud.craft_list.is_open(), "E at the work point opens the raft's list")


func test_solo_at_a_worn_raft() -> void:
	body.global_position = raft.global_position
	_frame()
	assert_same(hud.prompt.target, raft.interactable)
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Zarpar en la balsa", "Balsa 48/100", WARNING]))
	_key(KEY_E, true)
	for i: int in 12:
		_frame()
	_key(KEY_E, false)
	var routes := session.get_node("Routes") as IslandRoutes
	assert_true(routes.has_left(CoopSession.HOST_ID), "the warning never refuses: 1 s of E launches")
	assert_eq(routes.departure_integrity[&"raft"], 48.0)


func test_a_raft_at_half_or_more_shows_no_warning() -> void:
	raft.integrity = 90.0
	raft.max_integrity = 120.0
	body.global_position = raft.global_position
	_frame()
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Zarpar en la balsa", "Balsa 90/120"]))
	raft.integrity = 60.0
	_frame()
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Zarpar en la balsa", "Balsa 60/120"]), "60 is half: no warning")


func test_a_fitted_raft_lists_its_fittings_on_a_line_of_their_own() -> void:
	raft.integrity = 90.0
	raft.max_integrity = 120.0
	raft.fittings = [&"raft_clavazon", &"raft_toldo"] as Array[StringName]
	body.global_position = raft.global_position
	_frame()
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Zarpar en la balsa", "Balsa 90/120", "Clavazón · Toldo"]))
	var text := HudText.load_default()
	raft.fittings = [&"raft_clavazon", &"raft_defensas", &"raft_toldo"] as Array[StringName]
	assert_eq(InteractPrompt.raft_fittings_line(raft, text, "es"), "Clavazón · Defensas · Toldo", "all three fit the 30-glyph line")
	raft.fittings = [&"raft_clavazon", &"raft_toldo"] as Array[StringName]
	_open_list()
	assert_eq(hud.craft_list.head_texts(), PackedStringArray(["Balsa 90/120", "Clavazón · Toldo"]), "the list's head too")
	assert_eq(hud.craft_list.row_texts(), PackedStringArray(["Clavazón", "Defensas", "Remiendo", "Toldo"]), "the rows below both head lines")
	assert_true(hud.craft_list.row_dimmed(0), "the clavazón it has is dimmed")
	assert_false(hud.craft_list.row_dimmed(1), "the defensas it lacks are not")
	assert_true(hud.craft_list.row_dimmed(3), "nor a second toldo")
	assert_false(hud.craft_list.choose(3))
	assert_eq(hud.notice.shown_text(), "La balsa ya lo tiene.")
	assert_true(hud.craft_list.is_open(), "the list stays open")


func test_the_work_points_prompt() -> void:
	_at_work_point()
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Arreglar la balsa"]))


func test_solo_opens_the_rafts_list_on_the_coast_cay() -> void:
	body.inventory.add(&"nails", 4)
	body.inventory.add(&"driftwood", 1)
	body.inventory.add(&"rope", 1)
	_open_list()
	assert_eq(hud.craft_list.head_texts(), PackedStringArray(["Balsa 48/100"]))
	assert_eq(hud.craft_list.row_texts(), PackedStringArray(["Clavazón", "Defensas", "Remiendo", "Toldo"]))
	for row: int in 4:
		assert_false(hud.craft_list.row_dimmed(row), "row %d is open to a worn, bare raft" % row)
	assert_eq(hud.craft_list.detail_texts(), PackedStringArray(["4/4 Clavos"]), "the clavazón highlighted")
	hud.craft_list.highlight(2)
	assert_eq(hud.craft_list.detail_texts(), PackedStringArray(["1/1 Madera de la costa", "1/1 Soga"]), "the mend")
	assert_signal_emit_count(hud.craft_list, SENT, 0, "opening sends nothing")
	assert_false(get_tree().paused, "the list does not pause")


func test_a_whole_raft_refuses_a_mend() -> void:
	raft.integrity = 100.0
	_open_list()
	assert_true(hud.craft_list.row_dimmed(2), "dimmed")
	assert_false(hud.craft_list.row_dimmed(0), "a fitting still is not")
	assert_false(hud.craft_list.choose(2))
	assert_eq(hud.notice.shown_text(), "La balsa está entera.")
	assert_true(hud.craft_list.is_open(), "the list stays open")
	assert_signal_emit_count(hud.craft_list, SENT, 0, "nothing is sent")
	assert_null(raft.job)


func test_choosing_the_mend_opens_the_job_and_its_prompt_names_it() -> void:
	_open_list()
	assert_true(hud.craft_list.choose(2))
	assert_signal_emitted_with_parameters(hud.craft_list, SENT, [&"raft_mend", session.get_path_to(raft)])
	assert_false(hud.craft_list.is_open(), "a sent choice closes the list")
	assert_not_null(raft.job, "the host opened the mend")
	_key(KEY_E, false)
	_frame()
	assert_same(hud.prompt.target, raft.job.interactable, "the job is the candidate now")
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Trabajar en Remiendo", "Falta: Madera de la costa x1", "Soga x1"]))


func test_solo_mend_missing_its_rope() -> void:
	_at_work_point()
	assert_true(session.craft_for(CoopSession.HOST_ID, &"raft_mend", session.get_path_to(raft)), "the mend is open")
	body.inventory.add(&"driftwood", 1)
	_frame()
	_tap(KEY_E)
	assert_eq(body.inventory.count_id(&"driftwood"), 0, "the driftwood is deposited")
	_frame()
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Trabajar en Remiendo", "Falta: Soga x1"]))


func test_walking_away_closes_the_rafts_list() -> void:
	_open_list()
	body.global_position = raft.work_point.global_position + Vector2(0.0, 3.0 * IslandLayout.TILE)
	_frame()
	assert_false(hud.craft_list.is_open())
