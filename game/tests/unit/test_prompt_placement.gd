extends GutTest
## inventory-hud "Prompt placement" with exactly 1 player, offline, inside the game shell, so the
## world draws in WorldView's SubViewport and the prompt is mapped from it into the HUD as in a
## real run: centred over its target at whole pixels, its bottom edge 12 px above the target (over
## a player 3 px above its name tag's label on its head anchor, art-pass design.md P5), at most 240 px wide with "…", and kept inside
## x 4-636, y 22-302 off every HUD panel, the secret-cay needle and note included (the real ones:
## the player carries the broken compass, and the note label shows a long note). The prompt is
## ticked by hand.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_prompt_placement_settings.cfg"
const TILE: float = 16.0
const STEP_S: float = 0.1
const BOUNDS: Rect2 = Rect2(4.0, 22.0, 632.0, 280.0)
const OPEN_SAND: Vector2i = Vector2i(50, 18)
const TEAMMATE: int = 7

var shell: GameShell


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _start() -> PlayerBody:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(1)
	body.player_input.enabled = false
	return body


# The body at `at`; the camera follows it now, stopping at the island's bounds.
func _stand(body: PlayerBody, at: Vector2) -> void:
	body.global_position = at
	body.camera.reset_smoothing()
	body.camera.force_update_scroll()
	shell.hud.prompt.tick(STEP_S)


# `node`'s origin in HUD pixels, through the world view as the prompt maps it.
func _in_hud(node: CanvasItem) -> Vector2:
	return (shell.world_view.get_global_transform() * node.get_global_transform_with_canvas().origin).round()


func _panels() -> Array[Rect2]:
	var hud := shell.hud
	var rects: Array[Rect2] = [
		hud.meters.panel_rect(),
		(hud.get_node(^"PhasePanel") as Control).get_global_rect(),
		hud.strip.strip_rect(),
		hud.strip.item_line_panel.get_global_rect(),
		hud.notice.panel.get_global_rect(),
		hud.strip.weight_panel.get_global_rect(),
		hud.needle.get_global_rect(),
		hud.note_label.get_global_rect(),
	]
	if hud.teammates_panel.visible:
		rects.append(hud.teammates_panel.get_global_rect())
	return rects


# secret-cay's real needle (the local player carries the broken compass) and note label (showing
# the longest note entry, held up for the whole test).
func _add_secret_cay_pieces() -> void:
	var body := shell.session.body(1)
	body.inventory.add(&"brujula_rota", 1)
	shell.hud.needle.step(0.0)
	assert_true(shell.hud.needle.visible, "the real needle is up")
	var longest: String = ""
	var note := GameState.content.get_entry(&"items", &"nota_llegaste_tarde") as TextData
	for entry: TextEntryData in note.entries:
		if entry.body_es.length() > longest.length():
			longest = entry.body_es
	shell.hud.note_label.set_process(false)
	shell.hud.note_label.show_text(longest)
	assert_true(shell.hud.note_label.visible, "the real note label is up")


func _assert_placed(where: String) -> void:
	var prompt := shell.hud.prompt
	assert_true(prompt.visible, "a prompt %s" % where)
	var rect := prompt.prompt_rect()
	assert_true(BOUNDS.encloses(rect), "%s inside x 4-636, y 22-302 %s" % [rect, where])
	assert_eq(rect.position, rect.position.round(), "whole pixels %s" % where)
	for panel: Rect2 in _panels():
		assert_false(rect.intersects(panel), "%s clear of %s %s" % [rect, panel, where])


func test_centred_at_whole_pixels_with_its_bottom_12_px_above_the_target() -> void:
	var body := _start()
	var spot := IslandLayout.cell_center(OPEN_SAND)
	var wood := shell.session.spawn_pickup(&"driftwood", 1, spot + Vector2(5.0, 3.0))
	_stand(body, spot)
	var prompt := shell.hud.prompt
	assert_same(prompt.target, wood.interactable)
	var anchor := _in_hud(wood.interactable)
	var rect := prompt.prompt_rect()
	assert_eq(rect.position, rect.position.round(), "whole pixels")
	assert_almost_eq(rect.get_center().x, anchor.x, 0.5, "centred on the target's x")
	assert_eq(rect.end.y, anchor.y - 12.0, "its bottom edge 12 px above the target")
	assert_eq(prompt.panel.theme_type_variation, &"HudPanel", "on a HUD panel")
	assert_eq(prompt.panel.get_global_rect(), rect)


func test_over_a_downed_teammate_it_sits_above_the_name_tag() -> void:
	var body := _start()
	var session := shell.session
	session._add_player(TEAMMATE)
	session.roster[TEAMMATE] = "Papo"
	var papo := session.body(TEAMMATE)
	papo.player_input.enabled = false
	papo.meters.health = 40.0
	papo.set_downed(true)
	var spot := IslandLayout.cell_center(OPEN_SAND)
	papo.global_position = spot + Vector2(0.0, 6.0)
	var tag := papo.get_node(^"NameTag") as NameTag
	tag.refresh()
	assert_true(tag.visible, "the name tag shows over a hurt teammate")
	_stand(body, spot)
	var prompt := shell.hud.prompt
	assert_same(prompt.target, papo.drag_handle)
	assert_eq(prompt.lines()[0], "[E] Arrastrar a Papo")
	# art-pass "Head anchor" (design.md P5): 3 px above the tag's label on the downed head anchor.
	var anchor: float = (papo.get_node(^"BodyLook") as BodyLook).head_anchor_y()
	assert_eq(tag.position.y, anchor - NameTag.ANCHOR_GAP_PX, "the tag on the downed head anchor")
	var rect := prompt.prompt_rect()
	var label_rect := Rect2(_in_hud(tag.label), tag.label.size)
	assert_eq(rect.end.y, roundf(label_rect.position.y) - 3.0, "3 px above the tag's label")
	assert_false(rect.intersects(label_rect), "%s clear of the tag %s" % [rect, label_rect])
	assert_true(rect.end.y <= label_rect.position.y, "above it")


func test_at_most_240_px_wide_and_cut_with_an_ellipsis() -> void:
	var body := _start()
	var session := shell.session
	session._add_player(TEAMMATE)
	session.roster[TEAMMATE] = "Papo de los Palotes y Compañía Limitada"
	var papo := session.body(TEAMMATE)
	papo.player_input.enabled = false
	papo.set_downed(true)
	var spot := IslandLayout.cell_center(OPEN_SAND)
	papo.global_position = spot + Vector2(4.0, 0.0)
	_stand(body, spot)
	var prompt := shell.hud.prompt
	var lines := prompt.lines()
	assert_eq(lines.size(), 2, "too wide for one line: the name goes on the next")
	assert_eq(lines[0], "[E] Arrastrar a")
	assert_true(lines[1].begins_with("Papo de los Palotes"), lines[1])
	assert_true(lines[1].ends_with("…"), "still too wide: cut with an ellipsis: %s" % lines[1])
	assert_eq(lines[1].length(), 30, "30 glyphs of 8 px")
	assert_eq(prompt.prompt_rect().size, Vector2(240.0, 20.0), "at most 240 px wide, two 10 px lines")


func test_near_each_view_edge_it_stays_inside_and_off_every_panel() -> void:
	var body := _start()
	_add_secret_cay_pieces()
	var end := Vector2(shell.island.bounds.end)
	# Targets in the island's corners and edge middles, where the camera stops at the bounds.
	var targets: Dictionary[String, Vector2] = {
		"at the west edge": Vector2(6.0, end.y / 2.0),
		"at the east edge": Vector2(end.x - 6.0, end.y / 2.0),
		"at the north edge, under the needle": Vector2(end.x / 2.0, 6.0),
		"at the south edge": Vector2(end.x / 2.0, end.y - 6.0),
		"in the north-west corner, by the meters": Vector2(6.0, 6.0),
		"in the north-east corner": Vector2(end.x - 6.0, 6.0),
		"in the south-west corner": Vector2(6.0, end.y - 6.0),
		"in the south-east corner": Vector2(end.x - 6.0, end.y - 6.0),
	}
	for where: String in targets:
		var at: Vector2 = targets[where]
		var wood := shell.session.spawn_pickup(&"driftwood", 1, at)
		var beside := Vector2(clampf(at.x + 4.0, 0.0, end.x), clampf(at.y + 4.0, 0.0, end.y))
		_stand(body, beside)
		assert_same(shell.hud.prompt.target, wood.interactable, where)
		_assert_placed(where)
		wood.free()
