extends GutTest
## secret-cay "Empty chest", "Note on the HUD until the reading panel" and "Needle target" (the
## chest) with exactly 1 offline player on the secret cay: the chest stands on the chest cell, a
## 1 s hold opens it, exactly one note lies beside it and a second hold changes nothing; the note
## label shows the chosen Spanish body for 6 s plus 50 ms per character, then hides; the needle
## points at the unopened chest and spins once it is open. Time is stepped by hand.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const CAY_PATH: String = "res://resources/islands/cayo_sin_norte.tres"
const NOTE: StringName = &"nota_llegaste_tarde"
const FRAME_S: float = 1.0 / 60.0
const TILE: float = 16.0

var island: SandbarIsland
var session: CoopSession
var body: PlayerBody
var hud: RunHud
var chest: Chest


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = load(CAY_PATH) as IslandLayoutData
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.furnish(session)
	session.start()
	island.place_pickups(session)
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.auto_advance = false
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	hud.note_label.set_process(false)
	hud.needle.set_process(false)
	chest = session.get_node_or_null(NodePath(Chest.NAME)) as Chest
	if chest != null:
		chest.rng.seed = 7
		# West of the chest, in its reach and out of the reach of the note laid south of it.
		body.position = chest.position + Vector2(-TILE, 0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _hold(seconds: float) -> void:
	for i: int in roundi(seconds / FRAME_S):
		body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
		body.advance(FRAME_S)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, false)
	body.advance(FRAME_S)


func _notes() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == NOTE and not item.is_queued_for_deletion():
			found.append(item)
	return found


func test_the_chest_stands_on_the_chest_cell() -> void:
	assert_not_null(chest, "the cay's session holds the chest")
	if chest == null:
		return
	assert_eq(chest.position, IslandLayout.cell_center(island.built.chest))
	assert_false(chest.opened)
	assert_eq(chest.interactable.hold_time_s, 1.0, "the tuning's chest hold")
	assert_eq(chest.note_id, NOTE, "the layout's chest item")
	assert_eq(_notes().size(), 0, "no note before it opens")


func test_a_solo_player_opens_it() -> void:
	if chest == null:
		fail_test("no chest")
		return
	_hold(0.5)
	assert_false(chest.opened, "half a second opens nothing")
	_hold(1.0)
	assert_true(chest.opened, "a 1 s hold opens it")
	assert_ne(chest.entry_id, &"", "an entry was picked")
	await get_tree().process_frame
	var notes: Array[WorldItem] = _notes()
	assert_eq(notes.size(), 1, "exactly one note")
	if notes.size() == 1:
		assert_eq(notes[0].position, chest.position + Vector2(0.0, TILE), "beside the chest")
	var picked: StringName = chest.entry_id
	_hold(1.0)
	await get_tree().process_frame
	assert_eq(_notes().size(), 1, "the second hold lays no second note")
	assert_eq(chest.entry_id, picked, "nor picks another entry")
	assert_eq(body.inventory.count_id(NOTE), 0, "nor takes the note")


func test_a_solo_player_reads_the_note() -> void:
	if chest == null:
		fail_test("no chest")
		return
	_hold(1.0)
	var entry: TextEntryData = chest.entry(chest.entry_id)
	assert_not_null(entry)
	if entry == null:
		return
	var label: NoteLabel = hud.note_label
	assert_true(label.visible, "the note label shows")
	assert_eq(label.shown_text(), entry.body_es, "the chosen Spanish body")
	var seconds: float = 6.0 + 0.05 * entry.body_es.length()
	assert_almost_eq(label.time_left_s, seconds, 0.001, "6 s plus 50 ms per character")
	label.step(seconds - 0.1)
	assert_true(label.visible, "still up just before its time")
	label.step(0.2)
	assert_false(label.visible, "then it hides")


func test_a_120_character_body_shows_for_12_s() -> void:
	var label: NoteLabel = hud.note_label
	label.show_text("x".repeat(120))
	assert_almost_eq(label.time_left_s, 12.0, 0.001)


func test_the_needle_points_at_the_unopened_chest_then_spins() -> void:
	if chest == null:
		fail_test("no chest")
		return
	body.inventory.add(&"brujula_rota", 1)
	body.position = IslandLayout.cell_center(island.built.solo_spawn)
	hud.needle.step(0.05)
	assert_eq(hud.needle.target, chest as Node2D, "no concealed item: the chest")
	assert_almost_eq(hud.needle.bearing_rad, (chest.global_position - body.global_position).angle(), 0.001)
	body.position = chest.position + Vector2(-TILE, 0.0)
	_hold(1.0)
	hud.needle.step(0.05)
	assert_null(hud.needle.target, "an open chest is no target")
	assert_true(hud.needle.spinning, "it spins")


func test_a_peer_in_english_reads_the_english_body() -> void:
	if chest == null:
		fail_test("no chest")
		return
	session.locale = "en"
	_hold(1.0)
	var entry: TextEntryData = chest.entry(chest.entry_id)
	assert_eq(hud.note_label.shown_text(), entry.body_en, "the chosen English body")
