extends GutTest
## hud-clarity, island-generation "The hut note" and "The hut note's words", with exactly 1 player,
## offline: the sandbar holds one sign, glyph n, on the sand just south of the hut, reachable from the
## solo spawn and every co-op spawn; its lines name Florida, the north and the night, hold no digit
## and wrap to 8 lines or fewer; reading it opens the sign note and changes nothing else.

const SANDBAR_PATH: String = "res://resources/islands/sandbar.tres"
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const NOTE_GLYPH: String = "n"
## The hut's rows on the sandbar (tdHd, kHWH, HHHq) and the sand row south of them.
const HUT_ROWS: Array[int] = [14, 15, 16]
const SOUTH_ROW: int = 17

var settings_path: String = UserTmp.path("test_hut_note_settings.cfg")
var layout: IslandLayoutData
var built: IslandLayout


func before_each() -> void:
	layout = load(SANDBAR_PATH) as IslandLayoutData
	built = IslandLayout.build(layout)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _note() -> IslandSignData:
	for entry: IslandSignData in layout.signs:
		if entry.glyph == NOTE_GLYPH:
			return entry
	return null


func _note_cell() -> Vector2i:
	for entry: Dictionary in built.signs:
		if (entry["sign"] as IslandSignData).glyph == NOTE_GLYPH:
			return entry["cell"]
	return Vector2i(-1, -1)


func test_the_sandbar_has_one_sign_the_hut_note() -> void:
	assert_eq(layout.signs.size(), 1, "one sign")
	assert_not_null(_note(), "glyph n")
	var count: int = 0
	for row: String in layout.rows:
		count += row.count(NOTE_GLYPH)
	assert_eq(count, 1, "one n cell in the rows")
	assert_eq(layout.terrain_glyphs.get(NOTE_GLYPH, -1), DataEnums.Terrain.BEACH, "on sand")


func test_the_note_stands_just_south_of_the_hut() -> void:
	var cell := _note_cell()
	assert_eq(cell.y, SOUTH_ROW, "the row south of the hut")
	var above: String = layout.rows[HUT_ROWS[-1]]
	assert_true("HWtdkq".contains(above[cell.x]), "a hut cell right above it (%s)" % above[cell.x])
	assert_false(layout.shade_glyphs.contains(NOTE_GLYPH), "out of the hut's shade")


func test_every_spawn_reaches_the_note() -> void:
	var cell := _note_cell()
	var from_solo: Dictionary = built.reachable_from(built.solo_spawn)
	assert_true(from_solo.has(cell), "from the solo spawn")
	for spawn: Vector2i in built.coop_spawns:
		assert_true(built.reachable_from(spawn).has(cell), "from the co-op spawn %s" % spawn)


func test_the_words_name_the_goal() -> void:
	var note := _note()
	var es: String = note.text_es
	var en: String = note.text_en
	for word: String in ["la Florida", "norte", "noche"]:
		assert_string_contains(es, word)
	for word: String in ["Florida", "north", "night"]:
		assert_string_contains(en, word)
	var digit := RegEx.create_from_string("[0-9]")
	assert_null(digit.search(es), "no digit in Spanish")
	assert_null(digit.search(en), "no digit in English")
	for line: String in [es, en]:
		assert_between(SignNote.wrap_count(line), 1, SignNote.MAX_LINES, "wraps to 8 lines or fewer")


func test_the_rest_of_the_sandbar_is_unchanged() -> void:
	# The same layout with the note's cell back to plain sand and no sign builds the same island.
	var without := layout.duplicate(true) as IslandLayoutData
	var rows := PackedStringArray()
	for row: String in without.rows:
		rows.append(row.replace(NOTE_GLYPH, "."))
	without.rows = rows
	without.signs = [] as Array[IslandSignData]
	var plain := IslandLayout.build(without)
	assert_eq(built.palms, plain.palms, "palms")
	assert_eq(built.tide_pools, plain.tide_pools, "tide pools")
	assert_eq(built.pickups, plain.pickups, "pick-ups")
	assert_eq(built.coop_spawns, plain.coop_spawns, "co-op spawns")
	assert_eq(built.solo_spawn, plain.solo_spawn, "the solo spawn")
	assert_eq(built.raft_site, plain.raft_site, "the raft site")
	assert_eq(built.workbench, plain.workbench, "the workbench")
	var cell := _note_cell()
	assert_eq(built.terrain.terrain_at(cell), plain.terrain.terrain_at(cell), "the note stands on the same sand")


func test_a_solo_player_reads_the_hut_note() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(1)
	body.player_input.enabled = false
	var sign: IslandSign = null
	for child: Node in shell.session.get_children():
		if child is IslandSign:
			sign = child as IslandSign
	assert_not_null(sign, "the hut note is placed")
	if sign == null:
		return
	var items_before: int = body.inventory.slots.size()
	body.global_position = sign.global_position + Vector2(0.0, 12.0)
	body.camera.reset_smoothing()
	await wait_process_frames(2)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await wait_physics_frames(2)
	body.intent = MoveIntent.new()
	await wait_process_frames(2)
	assert_true(shell.hud.sign_note.is_open(), "E opens the sign note")
	assert_string_contains(shell.hud.sign_note.text_shown(), "la Florida")
	assert_eq(body.inventory.slots.size(), items_before, "reading changes nothing else")
