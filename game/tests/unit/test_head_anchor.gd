extends GutTest
## art-pass "Head anchor" (task 5.5; design.md P2-P6, P11), inside the game shell so the world draws
## in WorldView's SubViewport and the HUD maps it as in a real run. `BodyLook.head_y()` is the top
## of the drawn head in the current pose, measured from the composed look, and `head_anchor_y()` is
## 1 px above it. The name tag's origin sits 2 px above the anchor; the hidden mark, the interact
## prompt and a quick-chat bubble over a player stack upward from just above the anchor, or from
## above the tag while it shows, in that order, overlapping nowhere. The teammate is a second body
## added to a solo session by hand (as test_prompt_placement.gd does), so its tag shows here as on
## a client; a solo player's own mark uses the same anchor and the solo player has no tag.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_head_anchor_settings.cfg"
const ART_PATH: String = "res://assets/art/characters/balsero_art.tres"
const STEP_S: float = 0.1
const OPEN_SAND: Vector2i = Vector2i(50, 18)
const TEAMMATE: int = 7
const TAG_GAP_PX: float = 2.0
const STACK_GAP_PX: float = 3.0
const PROMPT_GAP_PX: float = 3.0
## design.md P6: over a speaker that is not a player, the top of the 16x16 sign post.
const SIGN_OFFSET: Vector2 = Vector2(0.0, -16.0)
const M := MovementStep.Move
const S := MovementStep.Stealth

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
	var body := shell.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	return body


# A hurt teammate, Papo, in slot 1 at `at`, its name tag showing.
func _teammate(at: Vector2) -> PlayerBody:
	var session := shell.session
	session._add_player(TEAMMATE)
	session.roster[TEAMMATE] = "Papo"
	var papo := session.body(TEAMMATE)
	papo.player_input.enabled = false
	papo.meters.health = 40.0
	papo.global_position = at
	_refresh(papo)
	return papo


func _stand(body: PlayerBody, at: Vector2) -> void:
	body.global_position = at
	body.camera.reset_smoothing()
	body.camera.force_update_scroll()


func _look(body: PlayerBody) -> BodyLook:
	return body.get_node(^"BodyLook") as BodyLook


func _tag(body: PlayerBody) -> NameTag:
	return body.get_node_or_null(^"NameTag") as NameTag


# Every head-placed piece over `body` follows its state now: its look, its tag, the HUD.
func _refresh(body: PlayerBody) -> void:
	var player_look := body.get_node_or_null(^"Look") as PlayerLook
	if player_look != null:
		player_look.step(STEP_S)
	_look(body).refresh()
	if _tag(body) != null:
		_tag(body).refresh()
	shell.hud.marks.tick()
	shell.hud.prompt.tick(STEP_S)
	var bubble := body.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)) as SpeechBubble
	if bubble != null:
		bubble.refresh()


func _anchor(slot: int, family: StringName) -> float:
	var art: BodyArt = load(ART_PATH) as BodyArt
	return float(LookComposer.compose(art.look_for_slot(slot)).head_anchor(family))


# A point in `body`'s own pixels, in HUD pixels.
func _hud_point(body: PlayerBody, local: Vector2) -> Vector2:
	return shell.world_view.get_global_transform() * (body.get_global_transform_with_canvas() * local)


# A world Control's rect, in HUD pixels.
func _hud_rect(control: Control) -> Rect2:
	var to_hud: Transform2D = shell.world_view.get_global_transform() * control.get_global_transform_with_canvas()
	return to_hud * Rect2(Vector2.ZERO, control.size)


func _crouch_hidden(body: PlayerBody) -> void:
	body.movement_state = M.CROUCH
	body.stealth_state = S.HIDDEN
	_refresh(body)


func test_the_head_anchor_is_1_px_above_the_drawn_head() -> void:
	var body: PlayerBody = _start()
	_stand(body, IslandLayout.cell_center(OPEN_SAND))
	_refresh(body)
	assert_eq(_look(body).head_anchor_y(), _anchor(0, &"walk"), "standing, from slot 0's composite")
	assert_eq(_look(body).head_y(), _anchor(0, &"walk") + 1.0)
	body.movement_state = M.CROUCH
	_refresh(body)
	assert_eq(_look(body).head_anchor_y(), _anchor(0, &"crouch"))
	body.movement_state = M.SWIM
	_refresh(body)
	assert_eq(_look(body).head_anchor_y(), _anchor(0, &"swim"))
	body.movement_state = M.DIVE
	_refresh(body)
	assert_eq(_look(body).head_anchor_y(), _anchor(0, &"dive"))
	body.movement_state = M.WALK
	body.set_downed(true)
	_refresh(body)
	assert_eq(_look(body).head_anchor_y(), _anchor(0, &"downed"))


func test_the_tag_follows_a_crouch_into_brush() -> void:
	# art-pass "The tag follows a crouch into brush".
	var body: PlayerBody = _start()
	var spot: Vector2 = IslandLayout.cell_center(OPEN_SAND)
	_stand(body, spot + Vector2(-24.0, 0.0))
	var papo: PlayerBody = _teammate(spot)
	var tag: NameTag = _tag(papo)
	assert_true(tag.visible, "the tag shows over a hurt teammate")
	assert_eq(papo.look_slot, 1)
	assert_eq(tag.position.y, _anchor(1, &"walk") - TAG_GAP_PX, "on the standing anchor")
	_crouch_hidden(papo)
	assert_eq(tag.position.y, _anchor(1, &"crouch") - TAG_GAP_PX, "moved down to the crouch anchor")
	assert_true(shell.hud.marks.has_mark(papo))
	var mark: Rect2 = shell.hud.marks.mark_rect(papo)
	var label: Rect2 = _hud_rect(tag.label)
	assert_false(mark.intersects(label), "%s clear of the tag %s" % [mark, label])
	assert_eq(mark.end.y, roundf(label.position.y) - STACK_GAP_PX, "the mark just above the tag")


func test_a_solo_players_mark_sits_just_above_the_crouch_anchor() -> void:
	# art-pass "A solo player's mark".
	var body: PlayerBody = _start()
	_stand(body, IslandLayout.cell_center(OPEN_SAND))
	_crouch_hidden(body)
	assert_null(_tag(body), "no name tag over a solo player")
	assert_true(shell.hud.marks.has_mark(body))
	var mark: Rect2 = shell.hud.marks.mark_rect(body)
	var head: Vector2 = _hud_point(body, Vector2(0.0, _anchor(0, &"crouch") + 1.0))
	assert_eq(mark.end.y, roundf(head.y) - STACK_GAP_PX, "just above the crouch anchor")
	_stand(body, body.global_position)
	body.movement_state = M.WALK
	body.stealth_state = S.HIDDEN
	_refresh(body)
	assert_lt(shell.hud.marks.mark_rect(body).end.y, mark.end.y, "standing, the mark is higher")


func test_a_bubble_over_a_teammate_sits_on_the_anchor_or_above_the_tag() -> void:
	var body: PlayerBody = _start()
	var spot: Vector2 = IslandLayout.cell_center(OPEN_SAND)
	_stand(body, spot + Vector2(-24.0, 0.0))
	var papo: PlayerBody = _teammate(spot)
	papo.meters.health = 100.0
	_refresh(papo)
	assert_false(_tag(papo).visible, "full health: no tag")
	var bubble: SpeechBubble = shell.session.show_bubble(papo, "¡Ayuda!")
	_refresh(papo)
	var label: Rect2 = _hud_rect(bubble.label)
	var anchor: Vector2 = _hud_point(papo, Vector2(0.0, _anchor(1, &"walk")))
	assert_almost_eq(label.end.y, anchor.y, 0.5, "on the head anchor")
	papo.meters.health = 40.0
	_refresh(papo)
	var tag_label: Rect2 = _hud_rect(_tag(papo).label)
	label = _hud_rect(bubble.label)
	assert_false(label.intersects(tag_label), "%s clear of the tag %s" % [label, tag_label])
	assert_true(label.end.y <= tag_label.position.y, "above the tag")


func test_a_bubble_over_a_sign_sits_at_the_sign_offset() -> void:
	_start()
	assert_eq(SpeechBubble.OFFSET, SIGN_OFFSET)
	var post := Node2D.new()
	shell.session.add_child(post)
	var bubble: SpeechBubble = shell.session.show_bubble(post, "Prohibido pescar")
	assert_eq(bubble.position, SIGN_OFFSET)


func test_the_prompt_over_a_downed_teammate_sits_3_px_above_the_tag() -> void:
	# inventory-hud "Over a downed teammate"; design.md P5.
	var body: PlayerBody = _start()
	var spot: Vector2 = IslandLayout.cell_center(OPEN_SAND)
	var papo: PlayerBody = _teammate(spot + Vector2(0.0, 6.0))
	papo.set_downed(true)
	_refresh(papo)
	_stand(body, spot)
	_refresh(papo)
	var prompt := shell.hud.prompt
	assert_same(prompt.target, papo.drag_handle)
	var tag: NameTag = _tag(papo)
	assert_eq(tag.position.y, _anchor(1, &"downed") - TAG_GAP_PX, "the tag on the downed anchor")
	var rect: Rect2 = prompt.prompt_rect()
	var label: Rect2 = _hud_rect(tag.label)
	assert_eq(rect.end.y, roundf(label.position.y) - PROMPT_GAP_PX, "3 px above the tag's label")
	assert_false(rect.intersects(label), "%s clear of the tag %s" % [rect, label])


func test_tag_prompt_and_bubble_over_a_downed_teammate_stack_upward() -> void:
	# art-pass "Head anchor"; design.md P11.
	var body: PlayerBody = _start()
	var spot: Vector2 = IslandLayout.cell_center(OPEN_SAND)
	var papo: PlayerBody = _teammate(spot + Vector2(0.0, 6.0))
	papo.set_downed(true)
	_stand(body, spot)
	var bubble: SpeechBubble = shell.session.show_bubble(papo, "¡Ayuda!")
	_refresh(papo)
	_refresh(papo)
	assert_same(shell.hud.prompt.target, papo.drag_handle, "the drag prompt is drawn")
	var tag: Rect2 = _hud_rect(_tag(papo).label)
	var prompt: Rect2 = shell.hud.prompt.prompt_rect()
	var said: Rect2 = _hud_rect(bubble.label)
	assert_false(tag.intersects(prompt), "tag %s and prompt %s" % [tag, prompt])
	assert_false(prompt.intersects(said), "prompt %s and bubble %s" % [prompt, said])
	assert_false(tag.intersects(said), "tag %s and bubble %s" % [tag, said])
	assert_true(prompt.end.y <= tag.position.y, "the prompt above the tag")
	assert_true(said.end.y <= prompt.position.y, "the bubble above the prompt")


func test_a_hidden_teammate_who_speaks_has_the_bubble_above_the_mark() -> void:
	var body: PlayerBody = _start()
	var spot: Vector2 = IslandLayout.cell_center(OPEN_SAND)
	_stand(body, spot + Vector2(-40.0, 0.0))
	var papo: PlayerBody = _teammate(spot)
	papo.meters.health = 100.0
	_crouch_hidden(papo)
	var bubble: SpeechBubble = shell.session.show_bubble(papo, "¡Agáchate!")
	_refresh(papo)
	_refresh(papo)
	assert_true(shell.hud.marks.has_mark(papo))
	var mark: Rect2 = shell.hud.marks.mark_rect(papo)
	var said: Rect2 = _hud_rect(bubble.label)
	assert_false(said.intersects(mark), "bubble %s and mark %s" % [said, mark])
	assert_true(said.end.y <= mark.position.y, "the bubble above the mark")
