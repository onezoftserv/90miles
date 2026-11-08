extends GutTest
## inventory-hud "Interact prompt", "Prompt verbs and targets" and "Key labels follow the device",
## with exactly 1 player, offline, on the sandbar: with no press held the prompt is over what
## InteractionPicker would pick for the local body now, nearest first; nothing in reach shows
## nothing; it hides while the player is down, the list is open, the run is paused, a screen is
## shown or the player has left; its words come from the HUD text file and the content names.
## The prompt is ticked by hand, with no frame awaited, so nothing moves under it.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/items/world_item.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const RAIN_CATCHER_SCENE: PackedScene = preload("res://scenes/structures/rain_catcher.tscn")
const RAFT_SCENE: PackedScene = preload("res://scenes/structures/raft.tscn")
const TILE: float = 16.0
const STEP_S: float = 0.1
## Open sand three tiles south of the hut's bench (the solo spawn), nothing within 7 tiles.
const OPEN_SAND: Vector2i = Vector2i(50, 18)
const SEAGULL_ID: StringName = &"seagull"

var island: SandbarIsland
var session: CoopSession
var hud: RunHud


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	get_tree().paused = false
	WeatherManager.stop()
	NetManager.leave()


# A solo run on the sandbar with its HUD; creatures only where the test asks for them.
func _run(with_creatures: bool = false) -> PlayerBody:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = with_creatures
	island.furnish(session)
	session.start()
	island.place_pickups(session)
	var body := session.body(1)
	body.player_input.enabled = false
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, true)
	return body


func _open_sand() -> Vector2:
	return IslandLayout.cell_center(OPEN_SAND)


func _tick() -> void:
	hud.prompt.tick(STEP_S)


func _stand(body: PlayerBody, at: Vector2) -> void:
	body.global_position = at
	_tick()


func _all() -> Array[Interactable]:
	var found: Array[Interactable] = []
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if node is Interactable:
			found.append(node as Interactable)
	return found


func _first_line() -> String:
	var lines := hud.prompt.lines()
	return lines[0] if not lines.is_empty() else ""


func _palm(index: int) -> Palm:
	return island.get_node("Palms").get_child(index) as Palm


func _pickup(item_id: StringName) -> WorldItem:
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == item_id and not item.is_queued_for_deletion():
			return item
	return null


func _place(scene: PackedScene, at: Vector2) -> Node2D:
	var made := scene.instantiate() as Node2D
	made.position = at
	session.add_child(made)
	return made


func _hold(body: PlayerBody, seconds: float) -> void:
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	for i: int in roundi(seconds / STEP_S):
		body.advance(STEP_S)
		_tick()


# --- which interactable ---------------------------------------------------------------------------

func test_with_no_press_the_prompt_is_the_pickers_choice_every_frame() -> void:
	var body := _run()
	var spots: Array[Vector2] = [
		session.get_node("HutWorkbench").global_position,
		_palm(0).global_position + Vector2(4.0, 0.0),
		_pickup(&"knife").global_position + Vector2(0.0, 6.0),
		session.get_node("RaftSite").global_position + Vector2(-10.0, 0.0),
		(session.get_node("RaftSite").global_position + _palm(0).global_position) / 2.0,
		_open_sand(),
	]
	var shown: int = 0
	for spot: Vector2 in spots:
		_stand(body, spot)
		var expected := InteractionPicker.pick(body.global_position, _all(), body)
		assert_same(hud.prompt.target, expected, "at %s" % spot)
		assert_eq(hud.prompt.visible, expected != null, "shown only with a candidate, at %s" % spot)
		if expected != null:
			shown += 1
	assert_gt(shown, 3, "most spots have something in reach")


func test_the_nearest_one_wins() -> void:
	var body := _run()
	var palm := _palm(0)
	body.global_position = palm.global_position + Vector2(0.9 * TILE, 0.0)
	var coconut := session.spawn_pickup(&"coco", 1, body.global_position + Vector2(0.0, 0.5 * TILE))
	_tick()
	assert_same(hud.prompt.target, coconut.interactable, "the coconut at 0.5 tiles, not the palm at 0.9")
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Recoger Coco"]))


func test_nothing_in_reach_shows_nothing() -> void:
	var body := _run()
	_stand(body, _open_sand())
	assert_null(InteractionPicker.pick(body.global_position, _all(), body), "2 tiles from everything")
	assert_null(hud.prompt.target)
	assert_false(hud.prompt.visible)


func test_hidden_while_down_with_the_list_paused_under_a_screen_or_gone() -> void:
	var body := _run()
	_stand(body, session.get_node("HutWorkbench").global_position)
	assert_true(hud.prompt.visible)
	body.set_downed(true)
	_tick()
	assert_false(hud.prompt.visible, "downed")
	body.set_downed(false)
	_tick()
	assert_true(hud.prompt.visible)
	hud.list_open = true
	_tick()
	assert_false(hud.prompt.visible, "the crafting list is open")
	hud.list_open = false
	_tick()
	assert_true(hud.prompt.visible)
	assert_true(hud.pause_menu.open())
	_tick()
	assert_false(hud.prompt.visible, "paused")
	hud.pause_menu.resume()
	_tick()
	assert_true(hud.prompt.visible)
	hud.set_screen_shown(true)
	_tick()
	assert_false(hud.prompt.visible, "the run summary shows")
	hud.set_screen_shown(false)
	_tick()
	assert_true(hud.prompt.visible)
	body.left_island = true
	_tick()
	assert_false(hud.prompt.visible, "left the island")


# --- what it says ----------------------------------------------------------------------------------

func test_the_sandbars_prompts() -> void:
	var body := _run(true)
	var sand := _open_sand()
	_stand(body, _pickup(&"knife").global_position)
	assert_eq(_first_line(), "[E] Recoger Cuchillo")
	_stand(body, _palm(0).global_position)
	assert_eq(_first_line(), "[E] Trepar Mata de coco")
	_stand(body, session.get_node("HutWorkbench").global_position)
	assert_eq(_first_line(), "[E] Fabricar en el banco")
	_stand(body, session.get_node("RaftSite").global_position)
	assert_eq(_first_line(), "[E] Construir Balsa")
	var fire := _place(FIRE_SCENE, sand) as Fire
	fire.light()
	_stand(body, fire.global_position)
	assert_eq(_first_line(), "[E] Apagar Fogata")
	var catcher := _place(RAIN_CATCHER_SCENE, sand + Vector2(3.0 * TILE, 0.0))
	_stand(body, catcher.global_position)
	assert_eq(_first_line(), "[E] Tomar Vaso de agua de lluvia")
	var raft := _place(RAFT_SCENE, sand + Vector2(-3.0 * TILE, 0.0))
	_stand(body, raft.global_position)
	assert_eq(_first_line(), "[E] Zarpar en la balsa")
	var gull: Creature = null
	for node: Node in session.entities.get_children():
		if node is Creature and (node as Creature).data.id == SEAGULL_ID:
			gull = node as Creature
	assert_not_null(gull, "the sandbar's gulls are out")
	if gull == null:
		return
	# Away from its nest palm, so the gull is the only thing in reach.
	gull.global_position = sand + Vector2(0.0, 3.0 * TILE)
	_stand(body, gull.global_position)
	assert_eq(_first_line(), "[E] Espantar Gaviota")


func test_a_bare_palm_still_reads_climb_and_the_climb_is_free() -> void:
	var body := _run()
	var palm := _palm(0)
	palm.coconuts = 0
	_stand(body, palm.global_position)
	assert_eq(_first_line(), "[E] Trepar Mata de coco")
	var energy: float = body.meters.energy
	_hold(body, 2.5)
	assert_eq(body.inventory.count_id(&"coco"), 0, "the climb gives nothing")
	assert_eq(body.meters.energy, energy, "and costs nothing")


func test_a_concealed_thing_names_only_itself() -> void:
	var body := _run()
	var hidden := WORLD_ITEM_SCENE.instantiate() as WorldItem
	hidden.item_id = &"coco"
	hidden.position = _open_sand()
	var spot := hidden.get_node("Interactable") as Interactable
	spot.prompt_id = &"climb_palm"
	spot.hides_contents = true
	session.add_child(hidden)
	_stand(body, hidden.global_position)
	assert_eq(_first_line(), "[E] Trepar Mata de coco")
	assert_false(_first_line().contains("Coco"), "never the item's name")


func test_no_prompt_id_shows_the_key_alone() -> void:
	var body := _run()
	var bare := Interactable.new()
	bare.hold_time_s = 0.0
	bare.position = _open_sand()
	session.add_child(bare)
	_stand(body, bare.global_position)
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E]"]))


func test_in_english_it_reads_pick_up_driftwood() -> void:
	var body := _run()
	session.locale = "en"
	var wood := session.spawn_pickup(&"driftwood", 1, _open_sand())
	_stand(body, wood.global_position)
	assert_eq(_first_line(), "[E] Pick up Driftwood")


func test_a_gamepad_button_turns_e_into_a() -> void:
	var body := _run()
	var coconut := session.spawn_pickup(&"coco", 1, _open_sand())
	_stand(body, coconut.global_position)
	assert_eq(_first_line(), "[E] Recoger Coco")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_Y
	button.pressed = true
	get_viewport().push_input(button)
	_tick()
	assert_eq(_first_line(), "[A] Recoger Coco")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	get_viewport().push_input(key)
	_tick()
	assert_eq(_first_line(), "[E] Recoger Coco", "a key press switches back")
