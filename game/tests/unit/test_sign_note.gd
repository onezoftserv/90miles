extends GutTest
## inventory-hud "Sign note" and "Closing the sign note", ui-shell "HUD layout" (the note's place) and
## island-generation "Flavour signs": the note a sign opens on the reader's HUD. It shows the sign's
## line in the game's language wrapped to a light card at (200, 22), 240 px wide and fitted to its
## text, then the close line with the device's key; it keeps clear of every other HUD piece; and every
## sign line of every island layout takes at most 8 lines of it, in both languages.

const NOTE_SCENE: PackedScene = preload("res://scenes/ui/sign_note.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const ISLAND_DIR: String = "res://resources/islands/"
const LINE_ES: String = "«AQUÍ NO SE RINDE NADIE» — y debajo, en carbón: «ni se queda nadie tampoco»."
const LINE_EN: String = "\"NOBODY SURRENDERS HERE\" - and under it, in charcoal: \"nobody stays either\"."
const CARD_X: float = 200.0
const CARD_Y: float = 22.0
const CARD_W: float = 240.0
const PADDING: Vector2 = Vector2(4.0, 3.0)
const LINE_H: float = 10.0
const GAP: float = 4.0

var note: SignNote
var body: PlayerBody
var sign_node: IslandSign


func before_each() -> void:
	WeatherManager.stop()
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	sign_node = IslandSign.new()
	sign_node.line_es = LINE_ES
	sign_node.line_en = LINE_EN
	add_child_autofree(sign_node)
	body.global_position = sign_node.global_position
	note = NOTE_SCENE.instantiate() as SignNote
	add_child_autofree(note)
	note.bind(body, null)


func after_each() -> void:
	WeatherManager.stop()



func test_open_shows_the_spanish_line_and_the_close_line() -> void:
	note.open(sign_node)
	assert_true(note.is_open())
	assert_true(note.visible)
	assert_eq(note.text_shown(), LINE_ES)
	assert_eq(note.close_text(), "[E] Cerrar")


func test_english_and_the_gamepad() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.locale = "en"
	note.bind(body, session)
	note.set_device(InputLabels.Device.GAMEPAD)
	note.open(sign_node)
	assert_eq(note.text_shown(), LINE_EN)
	assert_eq(note.close_text(), "[A] Close")
	note.set_device(InputLabels.Device.KEYBOARD)
	note._process(0.1)
	assert_eq(note.close_text(), "[E] Close", "the key follows the device while open")


func test_the_card_sits_at_200_22_and_is_240_wide_fitted_to_its_text() -> void:
	note.open(sign_node)
	var rect := note.card_rect()
	assert_eq(rect.position, Vector2(CARD_X, CARD_Y))
	assert_eq(rect.size.x, CARD_W)
	var lines: int = note.line_count()
	assert_between(lines, 1, SignNote.MAX_LINES)
	assert_eq(rect.size.y, 2.0 * PADDING.y + lines * LINE_H + GAP + LINE_H, "padding, the lines, a gap, the close line")
	# A short line makes a smaller card.
	sign_node.line_es = "Hola."
	note.close()
	note.open(sign_node)
	assert_eq(note.line_count(), 1)
	assert_eq(note.card_rect().size.y, 2.0 * PADDING.y + LINE_H + GAP + LINE_H)


func test_the_card_is_light_with_dark_text() -> void:
	note.open(sign_node)
	assert_eq(note.card.theme_type_variation, &"HudNote")
	assert_eq(note.text_label.theme_type_variation, &"HudNoteText")
	var fill: Color = (note.card.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color
	assert_eq(fill, HudStyle.CREAM)
	assert_eq(note.text_label.get_theme_color(&"font_color"), HudStyle.OUTLINE)
	assert_eq(note.text_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gte(_contrast(fill, HudStyle.OUTLINE), 7.0, "7:1 or more")


func _luminance(color: Color) -> float:
	var parts: Array[float] = []
	for channel: float in [color.r, color.g, color.b]:
		parts.append(channel / 12.92 if channel <= 0.03928 else pow((channel + 0.055) / 1.055, 2.4))
	return 0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]


func _contrast(a: Color, b: Color) -> float:
	var hi: float = maxf(_luminance(a), _luminance(b))
	var lo: float = minf(_luminance(a), _luminance(b))
	return (hi + 0.05) / (lo + 0.05)


func test_its_text_lies_inside_the_card() -> void:
	note.open(sign_node)
	var inner: Rect2 = note.card_rect().grow_individual(-PADDING.x, -PADDING.y, -PADDING.x, -PADDING.y)
	assert_true(inner.encloses(note.text_label.get_global_rect()), "%s in %s" % [note.text_label.get_global_rect(), inner])
	assert_true(note.card_rect().encloses(note.close_label.get_global_rect()))


func test_the_note_keeps_clear_of_every_hud_piece() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, false)
	var longest := IslandSign.new()
	longest.line_es = _longest_line("es")
	add_child_autofree(longest)
	var mine := session.body(1)
	longest.global_position = mine.global_position
	hud.sign_note.open(longest)
	assert_true(hud.sign_note.is_open())
	var rect: Rect2 = hud.sign_note.card_rect()
	var others: Dictionary = {
		"phase": hud.get_node("PhasePanel").get_global_rect(),
		"meters": hud.meters.panel_rect(),
		"teammates": hud.teammates_panel.get_global_rect(),
		"strip": hud.strip.strip_rect(),
		"centre": Rect2(240.0, 150.0, 160.0, 60.0),
	}
	for piece: String in others:
		assert_false(rect.intersects(others[piece] as Rect2), "the note %s clear of the %s %s" % [rect, piece, others[piece]])
	NetManager.leave()


func _longest_line(locale: String) -> String:
	var longest: String = ""
	for entry: IslandSignData in _all_signs():
		var line: String = entry.text_for(locale)
		if line.length() > longest.length():
			longest = line
	return longest


func _all_signs() -> Array[IslandSignData]:
	var found: Array[IslandSignData] = []
	for file: String in DirAccess.get_files_at(ISLAND_DIR):
		if not file.ends_with(".tres"):
			continue
		var layout := load(ISLAND_DIR + file) as IslandLayoutData
		if layout != null:
			found.append_array(layout.signs)
	return found


func test_every_sign_line_fits_in_at_most_8_lines_in_both_languages() -> void:
	var signs := _all_signs()
	assert_false(signs.is_empty(), "the layouts have signs")
	for entry: IslandSignData in signs:
		for locale: String in ["es", "en"]:
			var line: String = entry.text_for(locale)
			assert_false(line.is_empty(), "%s has a %s line" % [entry.glyph, locale])
			var lines: int = SignNote.wrap_count(line)
			assert_between(lines, 1, SignNote.MAX_LINES, "'%s' (%s) wraps to %d lines" % [line.left(30), locale, lines])
			sign_node.line_es = line
			sign_node.line_en = line
			note.close()
			note.open(sign_node)
			assert_eq(note.line_count(), lines, "the card and the data test count alike")
			assert_lte(note.card_rect().size.y, 2.0 * PADDING.y + SignNote.MAX_LINES * LINE_H + GAP + LINE_H)
			var inner_w: float = CARD_W - 2.0 * PADDING.x
			assert_lte(note.text_label.size.x, inner_w, "no line wider than the card's inner width")
