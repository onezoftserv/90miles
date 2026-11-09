extends GutTest
## inventory-hud "Crouch cue" and "Hidden mark" with exactly 1 player, offline (design D1, D9):
## holding crouch draws the body at 10 of its 16 px with its feet where they were, and full height
## again on release; crouching on brush puts a 7×5 closed-eye mark in the HUD layer, centred over
## the body with its bottom edge 3 px above the head (above the name tag when one shows), and it
## goes once the player steps onto sand; the night tint and the Suave filter do not touch it; a
## submerged diver gets none. The body and the HUD are stepped by hand from the real input state.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_body_look_settings.cfg"
const T := DataEnums.Terrain
const TILE: float = 16.0
const STEP_S: float = 0.1
## weather-daynight: 440.1 s after dawn is Noche (test_day_night_tint.gd).
const NIGHT_S: float = 440.1
## Brush west of x = 10, sand from there on.
const BRUSH: Rect2i = Rect2i(0, 0, 10, 12)
const IN_BRUSH: Vector2i = Vector2i(9, 5)
const MARK_SIZE: Vector2 = Vector2(7.0, 5.0)
const HEAD_GAP_PX: float = 3.0
const TEAMMATE: int = 7

var session: CoopSession
var hud: RunHud


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for keycode: Key in [KEY_C, KEY_D]:
		_key(keycode, false)
	WeatherManager.stop()
	NetManager.leave()
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.oversampling = true
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _grid(default_terrain: DataEnums.Terrain = T.BEACH) -> GridTerrain:
	var grid := GridTerrain.new()
	grid.default_terrain = default_terrain
	grid.fill_rect(BRUSH, T.SCRUB)
	return grid


# A solo session on `grid` with its HUD; the test steps the body from the input state itself.
func _solo(grid: GridTerrain, at: Vector2i) -> PlayerBody:
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = grid
	session.spawn_points = [_centre(at)] as Array[Vector2]
	add_child_autofree(session)
	session.start()
	var body := session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	return body


func _centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _look(body: PlayerBody) -> BodyLook:
	return body.get_node(^"BodyLook") as BodyLook


# One frame: the intent from the input, the body, its look, the HUD's marks.
func _frame(body: PlayerBody) -> void:
	body.intent = body.player_input.build_intent()
	body.advance(STEP_S)
	_look(body)._process(STEP_S)
	hud.marks._process(STEP_S)


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# Where the mark goes for `body` whose head is `head_y` px above (negative) or below its origin:
# centred on its x at whole pixels, its bottom edge 3 px above that point, in HUD pixels.
func _expected_mark(body: PlayerBody, top_y: float) -> Rect2:
	var anchor: Vector2 = hud.world_to_hud(body.get_global_transform_with_canvas().origin)
	var head: Vector2 = hud.world_to_hud(body.get_global_transform_with_canvas() * Vector2(0.0, top_y))
	var bottom: float = roundf(head.y) - HEAD_GAP_PX
	return Rect2(Vector2(roundf(anchor.x - MARK_SIZE.x / 2.0), bottom - MARK_SIZE.y), MARK_SIZE)


func test_holding_crouch_draws_the_body_10_px_tall_on_its_feet() -> void:
	var body := _solo(_grid(), Vector2i(20, 5))
	var look := _look(body)
	_frame(body)
	var standing := look.drawn_rect()
	assert_eq(standing.size, Vector2(16.0, 16.0), "16 px tall standing")
	_key(KEY_C, true)
	_frame(body)
	assert_eq(body.movement_state, MovementStep.Move.CROUCH)
	var lowered := look.drawn_rect()
	assert_eq(lowered.size.y, 10.0, "10 of its 16 px while crouching")
	assert_eq(lowered.size.x, 16.0, "as wide as before")
	assert_eq(lowered.end.y, standing.end.y, "its bottom edge, the feet, unchanged")
	_frame(body)
	assert_eq(look.drawn_rect(), lowered, "it stays lowered while crouch is held")
	_key(KEY_C, false)
	_frame(body)
	assert_eq(body.movement_state, MovementStep.Move.WALK)
	assert_eq(look.drawn_rect(), standing, "16 px again when they let go")
	var sprite := body.get_node(^"Sprite") as Sprite2D
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "still nearest-filtered")


func test_hidden_in_brush_the_mark_shows_over_the_head_until_sand() -> void:
	var body := _solo(_grid(), IN_BRUSH)
	_frame(body)
	assert_false(hud.marks.has_mark(body), "no mark standing in the brush")
	_key(KEY_C, true)
	_frame(body)
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN, "crouching on brush hides")
	assert_true(hud.marks.has_mark(body), "the mark shows over a hidden player")
	assert_true(hud.is_ancestor_of(hud.marks), "drawn by the HUD")
	assert_same(hud.marks.get_canvas_layer_node(), hud, "in the HUD's layer, not the world's")
	var head_y: float = _look(body).drawn_rect().position.y
	assert_eq(hud.marks.mark_rect(body), _expected_mark(body, head_y), "centred, its bottom 3 px above the crouched head")
	assert_eq(hud.marks.mark_rects().size(), 1)
	_key(KEY_D, true)
	for i: int in 20:
		_frame(body)
		if body.cell().x >= BRUSH.end.x:
			break
	assert_true(body.cell().x >= BRUSH.end.x, "walked onto the sand")
	_frame(body)
	assert_eq(body.stealth_state, MovementStep.Stealth.VISIBLE, "crouching on sand does not hide")
	assert_false(hud.marks.has_mark(body), "the mark goes on the sand")
	assert_eq(hud.marks.mark_rects().size(), 0)


func test_over_a_teammate_whose_name_tag_shows_it_sits_above_the_tag() -> void:
	var body := _solo(_grid(), Vector2i(20, 5))
	session._add_player(TEAMMATE)
	session.roster[TEAMMATE] = "Papo"
	var papo := session.body(TEAMMATE)
	papo.player_input.enabled = false
	papo.global_position = _centre(IN_BRUSH)
	papo.meters.health = 60.0
	var tag := papo.get_node(^"NameTag") as NameTag
	tag.refresh()
	assert_true(tag.visible, "a hurt teammate's tag shows")
	papo.intent = MoveIntent.create(Vector2.ZERO, false, true)
	papo.advance(STEP_S)
	_frame(body)
	assert_eq(papo.stealth_state, MovementStep.Stealth.HIDDEN)
	var tag_top: float = tag.position.y + tag.label.position.y
	var rect := hud.marks.mark_rect(papo)
	assert_eq(rect, _expected_mark(papo, tag_top), "3 px above the name tag's label")
	var label_rect := Rect2(hud.world_to_hud(tag.label.get_global_transform_with_canvas().origin), tag.label.size)
	assert_false(rect.intersects(label_rect), "clear of the tag")
	assert_false(hud.marks.has_mark(body), "the solo player is not hidden")


func test_a_submerged_diver_has_no_mark() -> void:
	var body := _solo(_grid(T.DEEP), Vector2i(20, 5))
	body.meters.energy = 100.0
	_key(KEY_C, true)
	_frame(body)
	assert_eq(body.stealth_state, MovementStep.Stealth.SUBMERGED, "crouch in deep water dives")
	assert_false(hud.marks.has_mark(body), "a diver gets no mark")
	assert_eq(hud.marks.mark_rects().size(), 0)


# --- night and Suave ----------------------------------------------------------------------------

# The colour every CanvasModulate on `item`'s canvas multiplies it by, times its own modulates and
# its CanvasItem parents'.
func _tint_on(item: CanvasItem) -> Color:
	var tint := Color.WHITE
	for node: Node in get_tree().root.find_children("*", "CanvasModulate", true, false):
		var modulate := node as CanvasModulate
		if modulate.is_visible_in_tree() and modulate.get_canvas() == item.get_canvas():
			tint *= modulate.color
	var at: Node = item
	while at is CanvasItem:
		tint *= (at as CanvasItem).modulate
		at = at.get_parent()
	return tint * item.self_modulate


# Whether a material (the Suave shader on the world view) sits on `item` or any CanvasItem above it,
# across viewports.
func _filtered(item: Node) -> bool:
	var at: Node = item
	while at != null:
		var canvas_item := at as CanvasItem
		if canvas_item != null and canvas_item.material != null:
			return true
		at = at.get_parent()
	return false


func _shell_smooth() -> GameShell:
	var settings := GameSettings.new(SETTINGS_PATH)
	settings.pixel_filter = PixelFilter.Mode.SMOOTH
	settings.save()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	return shell


func _brush_cell(terrain: GridTerrain, size: Vector2i) -> Vector2i:
	for y: int in size.y:
		for x: int in size.x:
			if TerrainQuery.is_brush(terrain.terrain_at(Vector2i(x, y))):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_at_noche_with_suave_on_the_mark_keeps_its_colours() -> void:
	var shell := _shell_smooth()
	hud = shell.hud
	session = shell.session
	var body := session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	var cell := _brush_cell(shell.island.terrain, shell.island.built.size)
	assert_ne(cell, Vector2i(-1, -1), "the sandbar has brush")
	body.global_position = _centre(cell)
	_key(KEY_C, true)
	_frame(body)
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN, "hidden in the sandbar's brush")
	assert_true(hud.marks.has_mark(body))
	var by_day: Array[Color] = []
	for colour: Color in hud.marks.mark_colors():
		by_day.append(colour * _tint_on(hud.marks))
	WeatherManager.sky.start_at(NIGHT_S)
	shell.tint._process(0.0)
	_frame(body)
	assert_eq(WeatherManager.phase(), DataEnums.DayPhase.NIGHT, "Noche")
	assert_not_null(shell.world_view.material, "Suave is on")
	var sprite := body.get_node(^"Sprite") as Sprite2D
	assert_false(_tint_on(sprite).is_equal_approx(Color.WHITE), "the night tints the world")
	assert_true(_filtered(sprite), "and Suave filters it")
	assert_true(hud.marks.has_mark(body), "still hidden at night")
	assert_false(_filtered(hud.marks), "Suave does not filter the mark")
	assert_false(shell.world_viewport.is_ancestor_of(hud.marks), "the mark is not in the world view")
	var at_night: Array[Color] = []
	for colour: Color in hud.marks.mark_colors():
		at_night.append(colour * _tint_on(hud.marks))
	assert_eq(at_night, by_day, "the same colours as by day")
	assert_eq(by_day.size(), 2, "the outline and the eye")
