extends GutTest
## inventory-hud "Slot contents" and "Slot tooltip" (hud-window-kit design D6), solo and offline with
## exactly one player: a tool's last use is orange; a slot whose use the button would refuse now is
## dimmed and never hidden (an item with no use and an empty slot never are); the dimming is worked
## out again when what it reads changes, not every frame; the tooltip names the item and its verb.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()


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


func _slot_of(hud: RunHud, id: StringName) -> int:
	var slots := hud.strip.body.inventory.slots
	for i: int in slots.size():
		if slots[i].item_id == id:
			return i
	return -1


func test_a_tools_last_use_is_orange() -> void:
	var hud := _hud()
	var inventory := hud.strip.body.inventory
	inventory.add(&"knife", 1, 1)
	inventory.add(&"lighter", 1, 20)
	var knife := hud.strip.slot_view(_slot_of(hud, &"knife"))
	var lighter := hud.strip.slot_view(_slot_of(hud, &"lighter"))
	assert_eq(knife.count_digits.text, "1")
	assert_true(knife.last_use(), "one use left")
	assert_eq(knife.count_digits.tone, HudDigits.Tone.ORANGE)
	assert_eq(lighter.count_digits.text, "20")
	assert_eq(lighter.count_digits.tone, HudDigits.Tone.CREAM)


func test_at_sea_a_usable_item_dims_and_one_with_no_use_does_not() -> void:
	var hud := _hud()
	var strip := hud.strip
	strip.body.meters.thirst = 50.0
	strip.body.inventory.add(&"rain_cup", 1)
	strip.body.inventory.add(&"driftwood", 1)
	var cup := strip.slot_view(_slot_of(hud, &"rain_cup"))
	var wood := strip.slot_view(_slot_of(hud, &"driftwood"))
	assert_false(cup.dimmed, "on land the cup can be drunk")
	# The player sets off on the raft: the session's routes hold them as departed, as a crossing does.
	var routes := strip.session.get_node_or_null(^"Routes") as IslandRoutes
	if routes == null:
		routes = IslandRoutes.new()
		routes.name = "Routes"
		strip.session.add_child(routes)
	routes.departed[1] = &"raft"
	assert_true(strip.at_sea())
	strip._process(0.0)
	assert_true(cup.dimmed, "the cup is dimmed on the crossing")
	assert_true(cup.icon.visible, "and still shown")
	assert_false(wood.dimmed, "driftwood has no use: never dimmed")


func test_a_coconut_with_no_blade_dims_until_a_knife_arrives() -> void:
	var hud := _hud()
	var strip := hud.strip
	strip.body.meters.thirst = 50.0
	strip.body.inventory.add(&"coco", 1)
	var coco := strip.slot_view(_slot_of(hud, &"coco"))
	assert_true(coco.dimmed, "no blade: the coconut's use is refused")
	assert_true(coco.icon.visible, "dimmed, never hidden")
	assert_true(coco.icon.modulate.is_equal_approx(StripSlot.DIM))
	strip.body.inventory.add(&"knife", 1)
	assert_false(coco.dimmed, "the knife opens it")
	assert_false(strip.slot_view(_slot_of(hud, &"knife")).dimmed, "the knife itself has no refused use")


func test_an_empty_slot_is_never_dimmed() -> void:
	var hud := _hud()
	for i: int in hud.strip.slot_count():
		assert_false(hud.strip.slot_view(i).dimmed, "slot %d" % (i + 1))


func test_the_dimming_is_not_worked_out_every_frame() -> void:
	var hud := _hud()
	var strip := hud.strip
	strip.body.meters.thirst = 50.0
	strip.body.inventory.add(&"coco", 1)
	await wait_process_frames(2)
	var before: int = strip.dimming_passes
	for i: int in 60:
		strip._process(0.0)
	assert_eq(strip.dimming_passes, before, "60 idle frames, no new pass")
	strip.body.meters.thirst = 20.0
	strip._process(0.0)
	assert_eq(strip.dimming_passes, before + 1, "a meter's change works it out again")


func test_the_tooltip_names_the_item_and_its_verb() -> void:
	var hud := _hud()
	var strip := hud.strip
	strip.body.inventory.add(&"knife", 1)
	strip.body.inventory.add(&"coco", 1)
	strip.body.inventory.add(&"driftwood", 1)
	strip.select(0)
	var coco := strip.slot_view(_slot_of(hud, &"coco"))
	assert_eq(coco.tooltip_text, "Coco · Beber", "name and verb")
	assert_eq(strip.slot_view(_slot_of(hud, &"driftwood")).tooltip_text, "Madera de la costa", "the name alone with no use")
	var empty := strip.slot_view(strip.slot_count() - 1)
	assert_eq(empty.tooltip_text, "", "no tooltip on an empty slot")
	assert_eq(strip.selected, 0, "a tooltip selects nothing")
	assert_eq(coco.focus_mode, Control.FOCUS_NONE, "and takes no focus")
