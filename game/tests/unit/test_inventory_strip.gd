extends GutTest
## inventory-hud "Inventory strip", "Slot contents", "The selected item's line" and "Strip follows
## the host", with exactly 1 player except where a teammate is the point: 12 slots of 26×26 px in
## the bottom band, the item line, the refusal line and the weight on HUD panels, and a strip that
## redraws on the frame the inventory changes.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const STRIP_SCENE: PackedScene = preload("res://scenes/ui/inventory_strip.tscn")
const SUN_YELLOW: Color = Color(1.0, 0.8, 0.0, 1.0)
const HERE: Vector2 = Vector2(100.0, 100.0)


func before_each() -> void:
	NetManager.start_solo()


func _session(extra: Array[int] = []) -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	for peer_id: int in extra:
		session._add_player(peer_id)
		session.roster[peer_id] = "Papo"
	for peer_id: int in session.peer_ids():
		session.body(peer_id).player_input.enabled = false
	session.body(CoopSession.HOST_ID).global_position = HERE
	return session


func _hud(session: CoopSession, local_peer: int = 1) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, local_peer, session.peer_ids().size() == 1)
	return hud


func _joypad_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_Y
	event.pressed = true
	return event


func _key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event


# --- layout ----------------------------------------------------------------------------------

func test_twelve_slots_of_26_px_across_the_bottom_band() -> void:
	var hud := _hud(_session())
	var strip := hud.strip
	assert_eq(strip.slot_count(), 12)
	assert_eq(strip.slot_view(0).get_global_rect(), Rect2(153.0, 330.0, 26.0, 26.0))
	assert_eq(strip.slot_view(1).get_global_rect().position, Vector2(181.0, 330.0), "2 px apart")
	assert_eq(strip.slot_view(11).get_global_rect().end, Vector2(487.0, 356.0))
	assert_eq(strip.strip_rect(), Rect2(153.0, 330.0, 334.0, 26.0))


func test_thirteen_slots_with_the_experiencia_slot() -> void:
	var session := _session()
	session.body(1).inventory.slots.append(InventorySlot.new())
	var hud := _hud(session)
	assert_eq(hud.strip.slot_count(), 13)
	assert_eq(hud.strip.strip_rect(), Rect2(139.0, 330.0, 362.0, 26.0))
	assert_eq(hud.strip.weight_panel.get_global_rect().position, Vector2(505.0, 339.0))
	assert_eq(hud.strip.slot_view(12).key_label.text, "", "no number key for the 13th slot")


func test_the_strip_and_its_lines_sit_on_hud_panels() -> void:
	var hud := _hud(_session())
	var strip := hud.strip
	strip.body.inventory.add(&"coco", 1)
	strip.refresh()
	var panels: Dictionary[String, PanelContainer] = {
		"strip": strip.panel,
		"item line": strip.item_line_panel,
		"refusal line": hud.notice.panel,
		"weight": strip.weight_panel,
	}
	for piece: String in panels:
		assert_eq(panels[piece].theme_type_variation, &"HudPanel", piece)
		assert_eq(panels[piece].mouse_filter, Control.MOUSE_FILTER_IGNORE, piece)
	assert_eq(strip.panel.get_global_rect(), strip.strip_rect())
	assert_eq(strip.item_line_panel.get_global_rect(), Rect2(153.0, 318.0, 334.0, 10.0))
	assert_eq(hud.notice.panel.get_global_rect(), Rect2(120.0, 306.0, 400.0, 10.0))
	assert_eq(strip.weight_panel.get_global_rect(), Rect2(491.0, 339.0, 100.0, 10.0))
	assert_eq(strip.item_line.get_global_rect().position, Vector2(153.0, 318.0))
	assert_eq(strip.weight_label.get_global_rect().position, Vector2(491.0, 339.0))


func test_the_band_overlaps_no_other_panel() -> void:
	var hud := _hud(_session([7] as Array[int]))
	hud.refresh()
	var others: Array[Rect2] = [
		hud.meters.panel_rect(),
		(hud.get_node(^"PhasePanel") as Control).get_global_rect(),
		hud.teammates_panel.get_global_rect(),
	]
	var band: Array[Rect2] = [
		hud.strip.strip_rect(),
		hud.strip.item_line_panel.get_global_rect(),
		hud.notice.panel.get_global_rect(),
		hud.strip.weight_panel.get_global_rect(),
	]
	var view := Rect2(0.0, 0.0, 640.0, 360.0)
	for piece: Rect2 in band:
		assert_true(view.encloses(piece), "inside the view: %s" % piece)
		assert_true(piece.position.y >= 306.0, "in the bottom band: %s" % piece)
		for other: Rect2 in others:
			assert_false(piece.intersects(other), "%s clear of %s" % [piece, other])


# --- slot contents ---------------------------------------------------------------------------

func test_a_stack_a_tool_and_an_empty_slot() -> void:
	var hud := _hud(_session())
	var strip := hud.strip
	var inventory := strip.body.inventory
	inventory.add(&"coco", 3)
	inventory.add(&"knife", 1, 39)
	var coco := strip.slot_view(0)
	assert_eq(coco.name_label.text, "Coc")
	assert_eq(coco.count_label.text, "3")
	assert_eq(coco.count_label.theme_type_variation, &"HudCount")
	assert_eq(coco.key_label.text, "1")
	assert_eq(coco.key_label.position, Vector2(2.0, 2.0), "the key top-left")
	var knife := strip.slot_view(1)
	assert_eq(knife.name_label.text, "Cuc")
	assert_eq(knife.count_label.text, "39", "uses left")
	var empty := strip.slot_view(2)
	assert_eq(empty.name_label.text, "")
	assert_eq(empty.count_label.text, "")
	assert_false(empty.icon.visible)
	assert_eq(empty.key_label.text, "3", "an empty slot keeps its frame and key")
	assert_eq(strip.weight_label.text, "Peso 2,5/30")


func test_a_single_item_shows_no_count() -> void:
	var hud := _hud(_session())
	hud.strip.body.inventory.add(&"driftwood", 1)
	assert_eq(hud.strip.slot_view(0).name_label.text, "Mad")
	assert_eq(hud.strip.slot_view(0).count_label.text, "")


func test_no_slot_keys_after_a_gamepad_button() -> void:
	var hud := _hud(_session())
	hud.strip.body.inventory.add(&"coco", 1)
	get_viewport().push_input(_joypad_button())
	for i: int in hud.strip.slot_count():
		assert_eq(hud.strip.slot_view(i).key_label.text, "", "slot %d" % (i + 1))
	get_viewport().push_input(_key_press(KEY_W))
	assert_eq(hud.strip.slot_view(0).key_label.text, "1", "back on the keyboard")


func test_the_selected_slot_has_the_sun_yellow_frame() -> void:
	var hud := _hud(_session())
	var strip := hud.strip
	assert_eq(strip.selected, 0, "screen slot 1 starts selected")
	strip.select(1)
	assert_true(strip.slot_view(1).selected)
	assert_false(strip.slot_view(0).selected)
	assert_eq(strip.slot_view(1).theme_type_variation, &"HudSlotSelected")
	assert_eq(strip.slot_view(0).theme_type_variation, &"HudSlot")
	var frame := strip.slot_view(1).get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_not_null(frame)
	if frame != null:
		assert_eq(frame.border_color, SUN_YELLOW)
		assert_eq(frame.border_width_left, 1)


func test_slots_never_take_focus() -> void:
	var hud := _hud(_session())
	for i: int in hud.strip.slot_count():
		assert_eq(hud.strip.slot_view(i).focus_mode, Control.FOCUS_NONE)
		assert_eq(hud.strip.slot_view(i).mouse_filter, Control.MOUSE_FILTER_STOP, "a slot takes clicks")


# --- the selected item's line ------------------------------------------------------------------

func test_name_key_and_verb() -> void:
	var hud := _hud(_session())
	var strip := hud.strip
	strip.body.inventory.add(&"coco", 1)
	strip.body.inventory.add(&"driftwood", 1)
	strip.select(0)
	strip.refresh()
	assert_eq(strip.item_line.text, "Coco · [F] Beber")
	strip.select(1)
	strip.refresh()
	assert_eq(strip.item_line.text, "Madera de la costa")
	strip.select(2)
	strip.refresh()
	assert_eq(strip.item_line.text, "")
	assert_false(strip.item_line_panel.visible, "no line for an empty slot")


func test_the_line_on_a_gamepad_shows_x() -> void:
	var hud := _hud(_session())
	hud.strip.body.inventory.add(&"coco", 1)
	get_viewport().push_input(_joypad_button())
	hud.strip.refresh()
	assert_eq(hud.strip.item_line.text, "Coco · [X] Beber")


func test_the_longest_line_cuts_the_teammates_name() -> void:
	var session := _session([7] as Array[int])
	session.roster[7] = "Papito Balserito"
	assert_eq(session.roster[7].length(), 16)
	var papo := session.body(7)
	papo.global_position = HERE + Vector2(8.0, 0.0)
	papo.meters.downed = true
	var hud := _hud(session)
	var strip := hud.strip
	strip.body.inventory.add(&"rain_cup", 1)
	strip.refresh()
	var line := strip.item_line.text
	assert_lte(line.length(), InventoryStrip.LINE_MAX_CHARS)
	assert_true(line.begins_with("Vaso de agua de lluvia · [F] Beber:"), line)
	assert_true(line.ends_with("…"), line)
	assert_eq(line, "Vaso de agua de lluvia · [F] Beber: Papi…")
	assert_eq(strip.item_line.get_line_count(), 1, "one line")
	assert_eq(strip.item_line.autowrap_mode, TextServer.AUTOWRAP_OFF, "never wraps onto the strip")


func test_a_short_teammate_name_is_kept_whole() -> void:
	assert_eq(InventoryStrip.item_line_text("Vaso de agua de lluvia", "F", "Beber", "Papo"), "Vaso de agua de lluvia · [F] Beber: Papo")


func test_a_long_item_name_is_cut_after_the_teammate() -> void:
	var line := InventoryStrip.item_line_text("Un nombre de cosa larguísimo de verdad", "F", "Beber", "Papo")
	assert_lte(line.length(), InventoryStrip.LINE_MAX_CHARS)
	assert_true(line.ends_with(" · [F] Beber: …"), line)
	assert_eq(InventoryStrip.item_line_text("Un nombre de cosa larguísimo de verdad, sí señor", "", "", ""), "Un nombre de cosa larguísimo de verdad, …")


func test_the_weight_uses_a_decimal_comma() -> void:
	assert_eq(InventoryStrip.weight_text(2.5, 30.0, "Peso"), "Peso 2,5/30")
	assert_eq(InventoryStrip.weight_text(4.5, 30.0, "Peso"), "Peso 4,5/30")
	assert_eq(InventoryStrip.weight_text(0.0, 30.0, "Peso"), "Peso 0/30")
	assert_eq(InventoryStrip.weight_text(12.0, 30.0, "Weight"), "Weight 12/30")


# --- following the inventory ---------------------------------------------------------------

func test_a_solo_pick_up_shows_on_the_same_frame() -> void:
	var session := _session()
	var hud := _hud(session)
	var me := session.body(1)
	var coconut := session.spawn_pickup(&"coco", 1, me.position + Vector2(4.0, 0.0))
	assert_eq(hud.strip.slot_view(0).name_label.text, "")
	(coconut.get_node(^"Interactable") as Interactable).use(me)
	assert_eq(me.inventory.slots[0].item_id, &"coco", "inventory slot 0 holds it")
	assert_eq(hud.strip.slot_view(0).name_label.text, "Coc", "screen slot 1 shows it at once")
	assert_eq(hud.strip.weight_label.text, "Peso 0,5/30")


func test_a_gull_taking_the_only_coconut_empties_its_slot_at_once() -> void:
	var rig := CreatureRig.make(self)
	rig.world.phase = DataEnums.DayPhase.DAY
	var body := rig.player(Vector2i(4, 9))
	body.inventory.add(&"coco", 1)
	var strip := STRIP_SCENE.instantiate() as InventoryStrip
	add_child_autofree(strip)
	strip.bind(body)
	strip.select(0)
	assert_eq(strip.slot_view(0).name_label.text, "Coc")
	rig.creature(&"seagull", Vector2i(4, 5))
	var left_s: float = 10.0
	while body.inventory.count_id(&"coco") > 0 and left_s > 0.0:
		rig.run(CreatureRig.STEP_S)
		left_s -= CreatureRig.STEP_S
	assert_eq(body.inventory.count_id(&"coco"), 0, "the gull took it")
	assert_eq(strip.slot_view(0).name_label.text, "", "the slot is empty on the same step")
	assert_eq(strip.selected, 0, "and stays selected")
	assert_true(strip.slot_view(0).selected)


func test_a_reclaimed_body_fills_the_strip() -> void:
	var session := _session([7] as Array[int])
	var reclaimed := session.body(7)
	reclaimed.inventory.add(&"driftwood", 2)
	var hud := _hud(session, 9)
	assert_null(hud.strip.body, "no body of its own yet")
	session._rebind_body(7, 9)
	assert_same(hud.strip.body, reclaimed)
	assert_eq(hud.strip.slot_view(0).name_label.text, "Mad")
	assert_eq(hud.strip.slot_view(0).count_label.text, "2")


func test_the_old_body_no_longer_redraws_the_strip() -> void:
	var session := _session([7] as Array[int])
	var hud := _hud(session)
	var other := session.body(7)
	hud.strip.bind(other, session)
	session.body(1).inventory.add(&"coco", 1)
	assert_eq(hud.strip.slot_view(0).name_label.text, "", "the first body is unbound")


func test_hidden_once_the_player_has_left_the_island() -> void:
	var session := _session()
	var hud := _hud(session)
	session.body(1).inventory.add(&"coco", 1)
	hud.strip._process(0.0)
	assert_true(hud.strip.visible)
	session.body(1).left_island = true
	hud.strip._process(0.0)
	assert_false(hud.strip.visible, "no strip and no lines")
	assert_false(hud.strip.is_visible_in_tree())
	assert_false(hud.notice.is_visible_in_tree())


func test_hidden_once_the_body_is_gone() -> void:
	var rig := CreatureRig.make(self)
	var body := rig.player(Vector2i(4, 9))
	var strip := STRIP_SCENE.instantiate() as InventoryStrip
	add_child_autofree(strip)
	strip.bind(body)
	body.free()
	strip._process(0.0)
	assert_false(strip.visible)
	strip.refresh()
	assert_false(strip.visible, "reads no freed body")
