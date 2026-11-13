extends GutTest
## art-pass "Creature frames from data", "Creature motion on every peer" and "Facing variants for
## creatures" (design.md D16, K1, K3, K15), pure: CreatureAnim picks a creature's animation from
## its frame names, its state name, its facing and whether it moves, plays a one-shot of the
## creature art data once on a state change, and counts a creature as moving while its drawn
## position changed within the last 0.15 s. No node, no peer: the same picture on every peer and
## with exactly 1 player.

const FRAME_S: float = 1.0 / 60.0
const SHARK_ART: String = "res://assets/art/creatures/creature_art.tres"
const SEAGULL: StringName = &"seagull"


# A SpriteFrames with one 1-frame looping animation per name, at `fps`.
func _frames(names: Array[StringName], fps: float = 8.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	for animation: StringName in names:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, fps)
		frames.add_frame(animation, texture)
	return frames


func _names(frames: SpriteFrames) -> PackedStringArray:
	return frames.get_animation_names()


func _shark_entry() -> CreatureArtEntry:
	var entry := CreatureArtEntry.new()
	entry.one_shots = {&"retreat": &"strike"}
	return entry


# --- pick ----------------------------------------------------------------------------------------

func test_a_state_name_picks_its_own_animation() -> void:
	var names := _names(_frames([&"idle", &"patrol", &"circle", &"move", &"strike"]))
	assert_eq(CreatureAnim.pick(names, &"circle", Vector2.RIGHT, true), &"circle")
	assert_eq(CreatureAnim.pick(names, &"patrol", Vector2.RIGHT, false), &"patrol", "a state's frames play whether or not it moves")
	assert_eq(CreatureAnim.pick(names, &"CIRCLE", Vector2.RIGHT, true), &"circle", "state names are read in lower case")


func test_a_state_without_frames_plays_move_while_moving_else_idle() -> void:
	var names := _names(_frames([&"idle", &"patrol", &"circle", &"move", &"strike"]))
	assert_eq(CreatureAnim.pick(names, &"retreat", Vector2.RIGHT, true), &"move")
	assert_eq(CreatureAnim.pick(names, &"retreat", Vector2.RIGHT, false), &"idle")
	assert_eq(CreatureAnim.pick(names, &"leave", Vector2.LEFT, true), &"move")


func test_facing_variants_win_over_plain_names() -> void:
	var names := _names(_frames([&"idle", &"swoop", &"swoop_down", &"swoop_up", &"swoop_side", &"move_up", &"move"]))
	assert_eq(CreatureAnim.pick(names, &"swoop", Vector2(0.3, -0.95), true), &"swoop_up", "a gull swooping mostly north")
	assert_eq(CreatureAnim.pick(names, &"swoop", Vector2(0.2, 0.98), true), &"swoop_down")
	assert_eq(CreatureAnim.pick(names, &"swoop", Vector2(-0.9, 0.3), true), &"swoop_side")
	assert_eq(CreatureAnim.pick(names, &"flee", Vector2.UP, true), &"move_up", "no flee frames: move_<facing> first")
	assert_eq(CreatureAnim.pick(names, &"flee", Vector2.DOWN, true), &"move", "then move")


func test_a_test_gull_with_swoop_frames_plays_swoop_up_and_the_shipped_gull_move_up() -> void:
	var fixture := _names(_frames([&"idle_side", &"idle_down", &"idle_up", &"swoop_down", &"swoop_up", &"swoop_side"]))
	var north := Vector2(0.4, -0.9)
	assert_eq(CreatureAnim.pick(fixture, &"swoop", north, true), &"swoop_up")
	var gull := GameState.content.get_entry(&"creatures", SEAGULL) as CreatureData
	assert_not_null(gull.sprite_frames, "the shipped seagull has frames")
	if gull.sprite_frames == null:
		return
	assert_eq(CreatureAnim.pick(_names(gull.sprite_frames), &"swoop", north, true), &"move_up")


func test_a_diagonal_tie_faces_sideways() -> void:
	var tie := Vector2(1.0, 1.0).normalized()
	assert_eq(CreatureAnim.facing_suffix(tie), &"side")
	assert_eq(CreatureAnim.facing_suffix(Vector2(-1.0, -1.0).normalized()), &"side")
	assert_eq(CreatureAnim.facing_suffix(Vector2(0.6, -0.8)), &"up")
	assert_eq(CreatureAnim.facing_suffix(Vector2(-0.6, 0.8)), &"down")
	var names := _names(_frames([&"idle_down", &"idle_up", &"idle_side"]))
	assert_eq(CreatureAnim.pick(names, &"perch", tie, false), &"idle_side")


func test_side_frames_are_mirrored_when_facing_left() -> void:
	assert_true(CreatureAnim.flipped(&"move_side", Vector2.LEFT))
	assert_false(CreatureAnim.flipped(&"move_side", Vector2.RIGHT))
	assert_true(CreatureAnim.flipped(&"idle_side", Vector2(-1.0, 1.0).normalized()), "a tie to the left is a side facing")
	assert_false(CreatureAnim.flipped(&"move_up", Vector2(-0.4, -0.9)), "an up variant is never mirrored")
	assert_false(CreatureAnim.flipped(&"idle_down", Vector2(-0.4, 0.9)), "nor a down one")
	assert_true(CreatureAnim.flipped(&"patrol", Vector2.LEFT), "frames with no variants are side-on")
	assert_false(CreatureAnim.flipped(&"patrol", Vector2.DOWN))


func test_pick_returns_only_names_the_frames_have() -> void:
	var only_idle := _names(_frames([&"idle"]))
	for state: StringName in [&"patrol", &"circle", &"swoop", &"pinch", &"perch"]:
		for facing: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1.0, 1.0).normalized()]:
			for moving: bool in [true, false]:
				assert_eq(CreatureAnim.pick(only_idle, state, facing, moving), &"idle")
	var only_move := _names(_frames([&"move"]))
	assert_eq(CreatureAnim.pick(only_move, &"wander", Vector2.RIGHT, false), &"", "nothing to play: no name at all")
	assert_eq(CreatureAnim.pick(PackedStringArray(), &"wander", Vector2.RIGHT, true), &"")


func test_idle_counts_as_present_with_idle_or_the_three_facing_variants() -> void:
	assert_true(CreatureAnim.has_idle(_names(_frames([&"idle"]))))
	assert_true(CreatureAnim.has_idle(_names(_frames([&"idle_down", &"idle_up", &"idle_side"]))))
	assert_false(CreatureAnim.has_idle(_names(_frames([&"idle_side"]))), "a side variant alone is not enough")
	assert_false(CreatureAnim.has_idle(_names(_frames([&"move", &"patrol"]))))


# --- motion window -------------------------------------------------------------------------------

func test_moving_means_the_drawn_position_changed_within_the_last_0_15_s() -> void:
	var anim := CreatureAnim.new()
	assert_false(anim.observe(Vector2(10.0, 10.0), FRAME_S), "the first position seen is no motion")
	assert_true(anim.observe(Vector2(11.0, 10.0), FRAME_S), "it changed")
	for frame: int in 8:
		assert_true(anim.observe(Vector2(11.0, 10.0), FRAME_S), "%.3f s after the change" % ((frame + 1) * FRAME_S))
	assert_false(anim.observe(Vector2(11.0, 10.0), FRAME_S), "0.15 s after the change")
	assert_true(anim.observe(Vector2(11.0, 12.0), FRAME_S), "and moving again on the next change")


func test_move_only_while_moving_else_idle() -> void:
	var frames := _frames([&"idle", &"move"])
	var entry := CreatureArtEntry.new()
	var anim := CreatureAnim.new()
	anim.observe(Vector2.ZERO, FRAME_S)
	assert_eq(anim.update(frames, entry, &"wander", Vector2.RIGHT, FRAME_S), &"idle")
	anim.observe(Vector2(2.0, 0.0), FRAME_S)
	assert_eq(anim.update(frames, entry, &"wander", Vector2.RIGHT, FRAME_S), &"move")
	for frame: int in 9:
		anim.observe(Vector2(2.0, 0.0), FRAME_S)
		anim.update(frames, entry, &"wander", Vector2.RIGHT, FRAME_S)
	assert_eq(anim.animation, &"idle", "0.15 s with no change")


func test_an_airborne_state_plays_move_whatever_the_motion() -> void:
	var frames := _frames([&"idle_side", &"idle_down", &"idle_up", &"move_side", &"move_down", &"move_up"])
	var entry := CreatureArtEntry.new()
	entry.airborne_states = PackedStringArray(["swoop", "flee", "return"])
	var anim := CreatureAnim.new()
	anim.observe(Vector2.ZERO, FRAME_S)
	assert_eq(anim.update(frames, entry, &"flee", Vector2.RIGHT, FRAME_S), &"move_side", "hovering in the air still flies")
	assert_eq(anim.update(frames, entry, &"perch", Vector2.RIGHT, FRAME_S), &"idle_side", "perched and still")


# --- one-shots -----------------------------------------------------------------------------------

func test_the_shark_plays_circle_then_strike_once_as_it_retreats_then_move() -> void:
	var frames := _frames([&"idle", &"patrol", &"circle", &"move"])
	frames.add_animation(&"strike")
	frames.set_animation_loop(&"strike", false)
	frames.set_animation_speed(&"strike", 8.0)
	var texture := ImageTexture.create_from_image(Image.create(32, 16, false, Image.FORMAT_RGBA8))
	for index: int in 3:
		frames.add_frame(&"strike", texture)
	var strike_s: float = CreatureAnim.length_s(frames, &"strike")
	assert_almost_eq(strike_s, 3.0 / 8.0, 0.0001, "3 frames at 8 fps")
	var entry := _shark_entry()
	var anim := CreatureAnim.new()
	var at := Vector2.ZERO
	var seen: Array[StringName] = []
	# CIRCLE (2) for 1 s, then RETREAT (4) for 1 s, moving all the while: STRIKE (3) is never held.
	for frame: int in 120:
		at += Vector2(1.0, 0.0)
		anim.observe(at, FRAME_S)
		var state: StringName = &"CIRCLE" if frame < 60 else &"RETREAT"
		var playing: StringName = anim.update(frames, entry, state, Vector2.RIGHT, FRAME_S)
		if seen.is_empty() or seen[-1] != playing:
			seen.append(playing)
	assert_eq(seen, [&"circle", &"strike", &"move"] as Array[StringName])
	var strike_frames: int = 0
	anim = CreatureAnim.new()
	anim.observe(at, FRAME_S)
	anim.update(frames, entry, &"circle", Vector2.RIGHT, FRAME_S)
	for frame: int in 60:
		at += Vector2(1.0, 0.0)
		anim.observe(at, FRAME_S)
		if anim.update(frames, entry, &"retreat", Vector2.RIGHT, FRAME_S) == &"strike":
			strike_frames += 1
	assert_almost_eq(strike_frames * FRAME_S, strike_s, FRAME_S, "strike plays once, for its own length")


func test_a_peer_that_first_sees_the_retreat_plays_no_strike() -> void:
	var frames := _frames([&"idle", &"move", &"strike"])
	var anim := CreatureAnim.new()
	anim.observe(Vector2.ZERO, FRAME_S)
	anim.observe(Vector2.ONE, FRAME_S)
	assert_eq(anim.update(frames, _shark_entry(), &"retreat", Vector2.RIGHT, FRAME_S), &"move", "joined mid-retreat")


func test_a_one_shot_the_frames_lack_is_skipped() -> void:
	var frames := _frames([&"idle", &"circle", &"move"])
	var anim := CreatureAnim.new()
	anim.observe(Vector2.ZERO, FRAME_S)
	anim.update(frames, _shark_entry(), &"circle", Vector2.RIGHT, FRAME_S)
	anim.observe(Vector2.ONE, FRAME_S)
	assert_eq(anim.update(frames, _shark_entry(), &"retreat", Vector2.RIGHT, FRAME_S), &"move")


func test_the_shipped_shark_art_plays_strike_on_entering_retreat() -> void:
	var art := load(SHARK_ART) as CreatureArt
	assert_not_null(art, "creature_art.tres loads")
	if art == null:
		return
	assert_eq(art.entry(&"reef_shark").one_shots, {&"retreat": &"strike"} as Dictionary[StringName, StringName])
