extends GutTest
## inventory-hud "Prompt verbs and targets" and "Prompt placement" on a crossing (CrossingRig, one
## offline session, no port open): the lashing reads "Amarrarse a la balsa" or "Soltarse de la
## balsa" by the rider's own state, a lone swimmer's climb point reads "Subir a la balsa" (both with
## exactly 1 player), and a teammate's pull handle reads "Jalar a Papo" and sits 3 px above the
## swimmer's name tag label on its head anchor (art-pass design.md P5), as over any player, clear of the hurt swimmer's name tag. The prompt is ticked by hand.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const STEP_S: float = 0.1
const SWIMMER: int = 2

# Freed before the session it reads.
var hud: RunHud = null


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	if is_instance_valid(hud):
		hud.free()
	hud = null
	WeatherManager.stop()
	NetManager.leave()


func _bind_hud(crossing: Crossing, solo: bool) -> RunHud:
	hud = HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	hud.bind(CoopSession.of(crossing), CoopSession.HOST_ID, solo)
	return hud


func _lines() -> PackedStringArray:
	hud.prompt.tick(STEP_S)
	return hud.prompt.lines()


# `node`'s origin in HUD pixels; with no world view the HUD reads the world's canvas directly.
func _in_hud(node: CanvasItem) -> Vector2:
	return hud.world_to_hud(node.get_global_transform_with_canvas().origin).round()


func test_the_lashing_reads_tie_down_or_untie_by_the_riders_own_state() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 90.0)
	var rider := crossing.body_of(1)
	_bind_hud(crossing, true)
	rider.global_position = crossing.deck_center()
	assert_eq(_lines(), PackedStringArray(["[E] Amarrarse a la balsa"]), "aboard and loose")
	crossing.tie(1)
	rider.global_position = crossing.deck_center()
	assert_eq(_lines(), PackedStringArray(["[E] Soltarse de la balsa"]), "tied down")


func test_a_lone_swimmer_is_offered_the_climb_point() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 90.0)
	var swimmer := crossing.body_of(1)
	crossing.throw_in(1)
	CrossingRig.put_beside_deck(crossing, swimmer, 8.0)
	CrossingRig.run(crossing, STEP_S)
	_bind_hud(crossing, true)
	assert_eq(_lines(), PackedStringArray(["[E] Subir a la balsa"]))


func test_a_pull_handle_names_the_swimmer_and_sits_above_their_name_tag() -> void:
	var crossing := CrossingRig.make(self, &"raft", 2, 60.0, 90.0)
	var session := CoopSession.of(crossing)
	session.roster[SWIMMER] = "Papo"
	var papo := crossing.body_of(SWIMMER)
	papo.meters.health = 40.0
	crossing.throw_in(SWIMMER)
	CrossingRig.put_beside_deck(crossing, papo, 1.0)
	CrossingRig.run(crossing, STEP_S)
	crossing.body_of(1).global_position = papo.global_position - Vector2(6.0, 0.0)
	_bind_hud(crossing, false)
	var tag := papo.get_node(^"NameTag") as NameTag
	tag.refresh()
	assert_true(tag.visible, "the name tag shows over a hurt swimmer")
	assert_eq(_lines(), PackedStringArray(["[E] Jalar a Papo"]))
	var rect := hud.prompt.prompt_rect()
	# art-pass "Head anchor" (design.md P5): 3 px above the tag's label on the swimmer's head anchor.
	var anchor: float = (papo.get_node(^"BodyLook") as BodyLook).head_anchor_y()
	assert_eq(tag.position.y, anchor - NameTag.ANCHOR_GAP_PX, "the tag on the swim head anchor")
	var label_top: float = _in_hud(tag.label).y
	assert_eq(rect.end.y, roundf(label_top) - 3.0, "3 px above the tag's label, as over any player")
	var strip := tag.get_node(^"Strip") as Control
	for part: Control in [tag.label, strip]:
		var part_rect := Rect2(_in_hud(part), part.size)
		assert_false(rect.intersects(part_rect), "%s clear of the tag's %s %s" % [rect, part.name, part_rect])
