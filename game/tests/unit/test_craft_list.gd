extends GutTest
## inventory-hud "Workbench crafting list", "Crafting list contents", "Choosing a recipe" and
## "Screens take input first" with exactly 1 player, offline, on the sandbar: E at the hut's bench
## opens the list at the left edge without pausing; it lists the known workbench recipes and the
## build-site structures by Spanish name with what each needs, dimmed where short; arrows, the
## D-pad, the wheel and the pointer move the highlight and E, A or a click choose; a refused choice
## keeps it open with its reason; walking away, going down, a screen, a sent choice or Esc close
## it, Esc before it can pause; and while it is open interact reaches the list alone. The body,
## the prompt and the list are stepped by hand from the real input state, with no frame awaited.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const GUT_LAYER: NodePath = ^"/root/GutRunner/GutLayer"
const STEP_S: float = 0.1
const TILE: float = 16.0
const LIST_RECT: Rect2 = Rect2(4.0, 162.0, 240.0, 140.0)
const SENT: String = "craft_sent"
## Off-centre in the hut cell south of the bench (51, 15), so the bench is the nearest thing and the
## rope lying one cell east is out of reach.
const AT_BENCH: Vector2 = Vector2(0.0, 10.0)

var island: SandbarIsland
var session: CoopSession
var hud: RunHud
var body: PlayerBody
var bench: Workbench
var _hid_gut_layer: bool = false


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for keycode: Key in [KEY_E, KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_F]:
		_key(keycode, false)
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		_joy(button, false)
	get_tree().paused = false
	var gut_layer := get_node_or_null(GUT_LAYER) as CanvasLayer
	if gut_layer != null and _hid_gut_layer:
		gut_layer.visible = true
	_hid_gut_layer = false
	WeatherManager.stop()
	NetManager.leave()


func _run() -> void:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	island.place_pickups(session)
	body = session.body(1)
	# The test steps the body itself, from the same input state PlayerInput reads.
	body.player_input.enabled = false
	bench = session.get_node("HutWorkbench") as Workbench
	body.global_position = bench.global_position + AT_BENCH
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, true)
	watch_signals(hud.craft_list)


# One frame: the intent from the input, the body (the host's interaction), the prompt, the list.
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


func _joy(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(keycode: Key) -> void:
	_key(keycode, true)
	_frame()
	_key(keycode, false)
	_frame()


func _tap_joy(button: JoyButton) -> void:
	_joy(button, true)
	_frame()
	_joy(button, false)
	_frame()


func _wheel(down: bool) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.position = Vector2(320.0, 150.0)
		event.global_position = event.position
		get_viewport().push_input(event, true)


func _hide_gut_layer() -> void:
	var gut_layer := get_node_or_null(GUT_LAYER) as CanvasLayer
	if gut_layer != null and gut_layer.visible:
		gut_layer.visible = false
		_hid_gut_layer = true


# The pointer over `at` (HUD coordinates), through the GUI.
func _point(at: Vector2) -> void:
	_hide_gut_layer()
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _click(at: Vector2) -> void:
	_hide_gut_layer()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)


# E at the bench: the list opens on the press.
func _open() -> void:
	_frame()
	assert_same(hud.prompt.target, bench.interactable, "the bench is the candidate")
	_tap(KEY_E)
	assert_true(hud.craft_list.is_open(), "E at the bench opens the list")


func _row_center(index: int) -> Vector2:
	return hud.craft_list.row_label(index).get_global_rect().get_center()


func _fire() -> RecipeData:
	return GameState.content.get_entry(&"recipes", &"fire") as RecipeData


# `count` workbench recipes known only to this player's crafter, "Prueba 00" first, each with three
# inputs, a tool and a speed-up: five detail lines under the highlighted one.
func _register_many(count: int) -> void:
	for i: int in count:
		var recipe := RecipeData.new()
		recipe.id = StringName("test_many_%02d" % i)
		recipe.name_es = "Prueba %02d" % i
		recipe.station = RecipeData.Station.WORKBENCH
		recipe.output_kind = RecipeData.OutputKind.ITEM
		recipe.output_item_id = &"rope"
		recipe.inputs = {&"driftwood": 1, &"tarp": 1, &"rope": 1}
		recipe.tools = [DataEnums.Capability.OPEN_COCONUT]
		recipe.fast_tool = DataEnums.Capability.PRY_NAILS
		recipe.time_s = 5.0
		body.crafter.register(recipe)


# Every row and detail line on show lies inside the list's panel.
func _assert_inside(where: String) -> void:
	for child: Node in hud.craft_list.get_children():
		var label := child as Label
		if label != null and label.visible:
			assert_true(LIST_RECT.encloses(label.get_global_rect()), "%s %s inside %s %s" % [label.text, label.get_global_rect(), LIST_RECT, where])


# A workbench recipe known only to this player's crafter, with a name longer than a row.
func _hook() -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = &"test_hook"
	recipe.name_es = "Anzuelo de alambre de la Esquina del Bote Viejo"
	recipe.station = RecipeData.Station.WORKBENCH
	recipe.output_kind = RecipeData.OutputKind.ITEM
	recipe.output_item_id = &"rope"
	recipe.inputs = {&"driftwood": 1, &"tarp": 1}
	recipe.time_s = 5.0
	return recipe


func _sites(recipe_id: StringName) -> Array[BuildSite]:
	var found: Array[BuildSite] = []
	for node: Node in get_tree().get_nodes_in_group(BuildSite.GROUP):
		var site := node as BuildSite
		if site != null and session.is_ancestor_of(site) and site.recipe.id == recipe_id and not site.is_queued_for_deletion():
			found.append(site)
	return found


# --- opening ----------------------------------------------------------------------------------------

func test_e_at_the_bench_opens_the_list_and_the_clock_keeps_running() -> void:
	_run()
	_open()
	assert_false(get_tree().paused, "the list does not pause")
	assert_true(session.can_process())
	assert_eq(hud.craft_list.panel.get_global_rect(), LIST_RECT, "4,162 to 244,302")
	assert_eq(hud.craft_list.panel.theme_type_variation, &"HudPanel")
	assert_true(hud.list_open, "the HUD knows the list holds the input")
	assert_false(hud.prompt.visible, "no prompt while it is open")
	assert_true(body.hud_holds_interact, "the intent carries no interact press meanwhile")
	assert_signal_emit_count(hud.craft_list, SENT, 0, "opening sends no craft request")


# --- contents ---------------------------------------------------------------------------------------

func test_the_sandbars_list_carrying_3_driftwood() -> void:
	_run()
	body.inventory.add(&"driftwood", 3)
	_open()
	var list := hud.craft_list
	assert_eq(list.row_texts(), PackedStringArray(["Fogata", "Recogedor de lluvia"]), "sorted by Spanish name")
	assert_eq(list.highlighted, 0)
	assert_eq(list.detail_texts(), PackedStringArray(["3/3 Madera de la costa", "0/1 Yesca", "Más rápido: prender candela"]))
	assert_false(list.detail_dimmed(0), "3/3 is carried")
	assert_true(list.detail_dimmed(1), "no tinder")
	assert_false(list.detail_dimmed(2), "the speed-up tool is never dimmed")
	assert_false(list.row_dimmed(0), "a build-site row is never dimmed")
	assert_false(list.row_dimmed(1))
	_assert_inside("for the sandbar")


func test_a_long_list_scrolls_inside_its_panel_and_keeps_the_highlight_shown() -> void:
	_run()
	_register_many(10)
	_open()
	var list := hud.craft_list
	var names: PackedStringArray = ["Fogata"]
	for i: int in 10:
		names.append("Prueba %02d" % i)
	names.append("Recogedor de lluvia")
	assert_eq(list.recipe_count(), 12, "all twelve are offered")
	# Down through every row and round again to the first.
	for at: int in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0]:
		assert_eq(list.highlighted, at)
		_assert_shown(at, names[at])
		_assert_inside("with row %d highlighted" % at)
		if at == 11:
			assert_true(list.row_texts().size() < 12, "not every row fits beside five detail lines")
			assert_eq(list.row_texts()[list.row_texts().size() - 1], "Recogedor de lluvia", "scrolled to the last")
			_point(_row_center(10))
			assert_eq(list.highlighted, 10, "the pointer picks the row under it in a scrolled list")
			_click(_row_center(9))
			assert_eq(list.highlighted, 9, "a click picks the row under it")
			assert_eq(hud.notice.shown_text(), "Te faltan materiales.", "and chooses that recipe")
			_tap(KEY_DOWN)
			_tap(KEY_DOWN)
		_tap(KEY_DOWN)
	assert_eq(list.row_texts()[0], "Fogata", "back at the top")
	assert_true(list.is_open())
	assert_signal_emit_count(list, SENT, 0)
	# The pointer leaves the rows before the HUD is freed.
	_point(Vector2(600.0, 100.0))


func _assert_shown(index: int, text: String) -> void:
	var shown := hud.craft_list.row_label(index)
	assert_not_null(shown, "row %d is on show while highlighted" % index)
	if shown != null:
		assert_true(shown.visible)
		assert_eq(shown.text, text)


func test_holding_f_with_the_list_open_uses_nothing_and_leaves_it_open() -> void:
	_run()
	body.meters.thirst = 50.0
	body.inventory.add(&"rain_cup", 1)
	hud.strip.select(0)
	watch_signals(hud.strip)
	_open()
	_key(KEY_F, true)
	for i: int in roundi(1.0 / STEP_S):
		_frame()
		hud.strip._process(STEP_S)
	assert_true(hud.craft_list.is_open(), "the list stays open")
	assert_eq(body.inventory.count_id(&"rain_cup"), 1, "nothing is used")
	assert_true(body.meters.thirst <= 50.0, "no drink")
	assert_signal_emit_count(hud.strip, "use_sent", 0, "nothing is sent")
	_key(KEY_F, false)
	_frame()


func test_a_partly_carried_input_is_dimmed() -> void:
	_run()
	body.inventory.add(&"driftwood", 2)
	_open()
	assert_eq(hud.craft_list.detail_texts()[0], "2/3 Madera de la costa")
	assert_true(hud.craft_list.detail_dimmed(0))


func test_a_new_workbench_recipe_shows_dimmed_cut_and_refused() -> void:
	_run()
	body.crafter.register(_hook())
	body.inventory.add(&"driftwood", 1)
	_open()
	var list := hud.craft_list
	var rows := list.row_texts()
	assert_eq(rows.size(), 3, "the registered recipe joins the list with no script change")
	assert_eq(rows[0], "Anzuelo de alambre de la Esq…", "a row over 29 glyphs ends in …")
	assert_eq(rows[0].length(), 29)
	assert_true(list.row_dimmed(0), "a workbench recipe missing an input is dimmed")
	assert_eq(list.detail_texts(), PackedStringArray(["1/1 Madera de la costa", "0/1 Lona"]))
	_tap(KEY_E)
	assert_eq(hud.notice.shown_text(), "Te faltan materiales.")
	assert_signal_emit_count(list, SENT, 0, "nothing is sent")
	assert_true(list.is_open(), "the list stays open")
	assert_eq(body.inventory.count_id(&"driftwood"), 1, "nothing is consumed")


func test_a_second_unfinished_fire_is_refused() -> void:
	_run()
	body.crafter.place_site(_fire(), IslandLayout.cell_center(Vector2i(50, 18)), session)
	_open()
	assert_eq(hud.craft_list.highlighted, 0, "Fogata")
	_tap(KEY_E)
	assert_eq(hud.notice.shown_text(), "Eso ya está en obra.")
	assert_signal_emit_count(hud.craft_list, SENT, 0, "no craft request")
	assert_true(hud.craft_list.is_open())
	assert_eq(_sites(&"fire").size(), 1, "no second site")


# --- moving and choosing -------------------------------------------------------------------------------

func test_arrows_the_d_pad_the_wheel_and_the_pointer_move_the_highlight() -> void:
	_run()
	_open()
	var list := hud.craft_list
	_tap(KEY_DOWN)
	assert_eq(list.highlighted, 1, "arrow down")
	_tap(KEY_UP)
	assert_eq(list.highlighted, 0, "arrow up")
	_tap_joy(JOY_BUTTON_DPAD_DOWN)
	assert_eq(list.highlighted, 1, "D-pad down")
	_tap_joy(JOY_BUTTON_DPAD_UP)
	assert_eq(list.highlighted, 0, "D-pad up")
	var selected: int = hud.strip.selected
	_wheel(true)
	assert_eq(list.highlighted, 1, "the wheel moves the list while it is open")
	assert_eq(hud.strip.selected, selected, "and not the strip")
	_wheel(false)
	assert_eq(list.highlighted, 0)
	_point(_row_center(1))
	assert_eq(list.highlighted, 1, "the pointer over a row")
	for i: int in list.row_texts().size():
		assert_eq(list.row_label(i).focus_mode, Control.FOCUS_NONE, "row %d takes no focus" % i)
	assert_null(get_viewport().gui_get_focus_owner(), "nothing took focus")
	assert_true(list.is_open(), "moving chooses nothing")
	assert_signal_emit_count(list, SENT, 0)


func test_e_chooses() -> void:
	_run()
	_open()
	_tap(KEY_E)
	assert_signal_emitted_with_parameters(hud.craft_list, SENT, [&"fire", session.get_path_to(bench)])
	assert_false(hud.craft_list.is_open(), "a sent choice closes the list")
	assert_eq(_sites(&"fire").size(), 1, "the host placed the site")


func test_a_on_a_gamepad_chooses() -> void:
	_run()
	_open()
	_tap(KEY_DOWN)
	_tap_joy(JOY_BUTTON_A)
	assert_signal_emitted_with_parameters(hud.craft_list, SENT, [&"rain_catcher", session.get_path_to(bench)])
	assert_false(hud.craft_list.is_open())


func test_a_click_chooses() -> void:
	_run()
	_open()
	_click(_row_center(1))
	assert_signal_emitted_with_parameters(hud.craft_list, SENT, [&"rain_catcher", session.get_path_to(bench)])
	assert_false(hud.craft_list.is_open())


# --- closing ----------------------------------------------------------------------------------------

func test_walking_away_going_down_or_a_screen_closes_it() -> void:
	_run()
	_open()
	body.global_position = bench.global_position + Vector2(0.0, 2.0 * TILE)
	_frame()
	assert_false(hud.craft_list.is_open(), "2 tiles away")
	body.global_position = bench.global_position + AT_BENCH
	_open()
	body.set_downed(true)
	_frame()
	assert_false(hud.craft_list.is_open(), "down")
	body.set_downed(false)
	_frame()
	_open()
	hud.set_screen_shown(true)
	_frame()
	assert_false(hud.craft_list.is_open(), "a screen")
	assert_false(hud.list_open)
	assert_signal_emit_count(hud.craft_list, SENT, 0)


func test_the_first_esc_closes_it_and_the_second_pauses() -> void:
	_run()
	_open()
	_tap(KEY_ESCAPE)
	assert_false(hud.craft_list.is_open(), "the first Esc closes the list")
	assert_false(get_tree().paused, "and does not pause")
	assert_false(hud.pause_menu.visible)
	_tap(KEY_ESCAPE)
	assert_true(hud.pause_menu.visible, "the second opens the pause menu")
	assert_true(get_tree().paused)


func test_with_the_list_open_e_reaches_the_list_alone() -> void:
	_run()
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	_open()
	var wood := session.spawn_pickup(&"driftwood", 1, body.global_position + Vector2(-9.0, 0.0))
	_key(KEY_E, true)
	for i: int in 3:
		_frame()
	assert_signal_emitted(hud.craft_list, SENT, "the E chose Fogata")
	var sites := _sites(&"fire")
	assert_eq(sites.size(), 1)
	if sites.is_empty():
		return
	var site := sites[0]
	assert_eq(site.position, IslandLayout.cell_center(body.cell()), "on the cell under the player")
	_key(KEY_E, false)
	_frame()
	assert_true(is_instance_valid(wood) and wood.interactable.enabled, "the driftwood stays on the ground")
	assert_true(site.deposited.is_empty() and site.tags_deposited.is_empty(), "the E that chose deposits nothing")
	assert_eq(body.inventory.count_id(&"driftwood"), 3)
	assert_false(body.hud_holds_interact, "released, interact is the player's again")
	assert_eq(hud.prompt.lines()[0], "[E] Construir Fogata")
	_tap(KEY_E)
	assert_eq(site.deposited.get(&"driftwood", 0), 3, "a fresh press deposits into the new site")
