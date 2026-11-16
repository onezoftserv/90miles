extends GutTest
## ui-shell "Shared theme" and "HUD layout", inventory-hud "Inventory strip" (hud-window-kit design
## D3, D8): with exactly one offline player, the run HUD's pieces sit on the kit's windows at the
## rects the specs pin. The dark windows (meters, phase, watching line) hold their text inside their
## 3 px frame; the 10 px rows (prompt, item line, refusal line, weight) are thin windows with their
## text 1 px down; the strip's backdrop reaches 1-2 px past the slots, clear of the item line and the
## weight; the sign note is the cream paper window; every text reads on its window.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SMALL_FONT: String = "res://assets/fonts/PressStart2P-Regular.ttf"
const DARK: String = "res://assets/art/ui/window_dark.png"
const THIN: String = "res://assets/art/ui/window_thin.png"
const PAPER: String = "res://assets/art/ui/window_paper.png"


func before_each() -> void:
	NetManager.start_solo()


func _hud() -> RunHud:
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	session.body(1).player_input.enabled = false
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, true)
	return hud


func _piece(box: Control) -> String:
	var style := box.get_theme_stylebox(&"panel") as StyleBoxTexture
	return style.texture.resource_path if style != null else ""


func test_the_dark_windows() -> void:
	var hud := _hud()
	await wait_process_frames(2)
	assert_eq(_piece(hud.meters.get_node(^"Panel") as Control), DARK, "meters")
	assert_eq(_piece(hud.get_node(^"PhasePanel") as Control), DARK, "phase")
	assert_eq(_piece(hud.watching_panel), DARK, "watching line")
	assert_eq((hud.get_node(^"PhasePanel") as Control).get_global_rect(), Rect2(260.0, 4.0, 120.0, 14.0), "the phase keeps its rect")
	var phase := hud.phase_label.get_global_rect()
	assert_true(Rect2(263.0, 7.0, 114.0, 8.0).encloses(Rect2(phase.position, Vector2(phase.size.x, 8.0))), "the phase's text inside the 3 px frame: %s" % phase)


func test_the_thin_rows_keep_their_rects() -> void:
	var hud := _hud()
	var strip := hud.strip
	strip.body.inventory.add(&"coco", 1)
	strip.refresh()
	hud.notice.show_line("No tienes nada ahí.")
	await wait_process_frames(2)
	for row: PanelContainer in [strip.item_line_panel, strip.weight_panel, hud.notice.panel]:
		assert_eq(_piece(row), THIN, row.name)
	assert_eq(strip.item_line_panel.get_global_rect(), Rect2(153.0, 318.0, 334.0, 10.0))
	assert_eq(hud.notice.panel.get_global_rect(), Rect2(120.0, 306.0, 400.0, 10.0))
	assert_eq(strip.weight_panel.get_global_rect(), Rect2(491.0, 339.0, 100.0, 10.0))


func test_the_strip_backdrop_reaches_past_the_slots_and_stays_clear() -> void:
	var hud := _hud()
	await wait_process_frames(2)
	var strip := hud.strip
	var style := strip.panel.get_theme_stylebox(&"panel") as StyleBoxTexture
	assert_eq(style.texture.resource_path, THIN)
	var drawn: Rect2 = strip.panel.get_global_rect()
	drawn = drawn.grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)
	assert_eq(drawn, Rect2(151.0, 329.0, 338.0, 29.0), "drawn from (151,329) to (489,358)")
	assert_false(drawn.intersects(strip.item_line_panel.get_global_rect()), "clear of the item line")
	assert_false(drawn.intersects(strip.weight_panel.get_global_rect()), "clear of the weight")
	assert_lte(drawn.end.y, 360.0, "inside the view")


func test_prompt_lines_start_one_pixel_down_their_rows() -> void:
	var hud := _hud()
	var prompt := hud.prompt
	assert_eq(_piece(prompt.panel), THIN, "the prompt is a thin window")
	prompt.size = Vector2(160.0, 20.0)
	prompt._set_lines(PackedStringArray(["[E] Construir Balsa", "Falta: Soga x3"]), [0.0, 8.0] as Array[float])
	var labels: Array[Label] = prompt._labels
	assert_eq(labels[0].position, Vector2(0.0, 1.0), "the first line 1 px down")
	assert_eq(labels[1].position, Vector2(8.0, 11.0), "the second 1 px down its row")
	for label: Label in labels:
		assert_lte(label.position.y + label.size.y, 20.0, "inside the box")


func test_the_sign_note_is_cream_paper_and_the_list_pads_its_frame() -> void:
	var hud := _hud()
	assert_eq(_piece(hud.sign_note.card), PAPER, "the sign note")
	assert_eq(SignNote.POSITION, Vector2(200.0, 22.0))
	assert_eq(SignNote.WIDTH, 240.0)
	assert_gte(SignNote.PADDING.y, 3.0, "the note's first line clears its 3 px frame")
	assert_gte(CraftList.PADDING.y, 3.0, "the list's first line clears its 3 px frame")
	assert_gte(CraftList.PADDING.x, 4.0)
	assert_eq(_piece(hud.craft_list.panel), DARK, "the craft list")


func test_every_hud_label_is_the_small_font_and_reads_on_its_window() -> void:
	var hud := _hud()
	hud.strip.body.inventory.add(&"coco", 3)
	hud.strip.refresh()
	hud.notice.show_line("No tienes nada ahí.")
	await wait_process_frames(2)
	var labels: Array[Node] = hud.find_children("*", "Label", true, false)
	var checked: int = 0
	for node: Node in labels:
		var label := node as Label
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		assert_eq(label.get_theme_font(&"font").resource_path, SMALL_FONT, label.text)
		assert_eq(label.get_theme_font_size(&"font_size"), 8, label.text)
		var fill: Color = _fill_under(label)
		if fill.a == 0.0:
			continue
		var ink: Color = label.get_theme_color(&"font_color")
		var floor_ratio: float = HudContrast.ALERT if label.theme_type_variation == &"AlertLabel" else HudContrast.STEADY
		assert_gte(HudContrast.ratio(ink, fill), floor_ratio, "'%s' reads on its window" % label.text)
		checked += 1
	assert_gt(checked, 3, "the meters, the phase and the lines were checked")


# The fill of the window a label sits on: its nearest PanelContainer ancestor, or else the visible
# thin row whose rect holds it (the strip's lines are siblings of their panels).
func _fill_under(label: Label) -> Color:
	var node: Node = label.get_parent()
	while node != null:
		var box := node as PanelContainer
		if box != null:
			var piece: String = _piece(box)
			return HudContrast.centre_color(piece) if not piece.is_empty() else Color.TRANSPARENT
		node = node.get_parent()
	for row: Node in label.get_tree().root.find_children("*", "PanelContainer", true, false):
		var box := row as PanelContainer
		if box.is_visible_in_tree() and box.get_global_rect().encloses(label.get_global_rect().grow(-1.0)):
			return HudContrast.centre_color(_piece(box))
	return Color.TRANSPARENT
