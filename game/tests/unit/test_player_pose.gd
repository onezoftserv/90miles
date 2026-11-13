extends GutTest
## art-pass "Player poses" and "Dead is not downed" (task 5.1), pure: `PlayerPose` picks a pose from
## the states every peer already has (movement, stealth, downed, dead) and whether the drawn body
## moves, and gives each pose its animation in balsero_frames.tres, its sprite offset (swim and
## float 12 px lower, through `offset`), its speed or still frame, whether the water line, the
## shadow and the dive ripple show, and its mirroring (design.md D3 as amended by C1). Every case
## is one player's body: a solo player sees exactly these poses.

const FRAMES_PATH: String = "res://assets/art/characters/balsero_frames.tres"
const M := MovementStep.Move
const S := MovementStep.Stealth
const P := PlayerPose.Pose
const F := Facing.Dir
## design.md C1 D1: frames drawn with centered off at (-16, -27), so row 30 ends at +4.
const OFFSET: Vector2 = Vector2(-16.0, -27.0)
const SWIM_DROP_PX: float = 12.0
const FACINGS: Array[Facing.Dir] = [Facing.Dir.DOWN, Facing.Dir.UP, Facing.Dir.LEFT, Facing.Dir.RIGHT]


func _pick(movement: MovementStep.Move, moving: bool = true, stealth: MovementStep.Stealth = S.VISIBLE, downed: bool = false, dead: bool = false) -> PlayerPose.Pose:
	return PlayerPose.pick(movement, stealth, downed, dead, moving)


func test_walking_and_running_bodies_walk_and_a_still_one_stands() -> void:
	assert_eq(_pick(M.WALK), P.WALK)
	assert_eq(_pick(M.RUN), P.RUN)
	assert_eq(_pick(M.WALK, false), P.STANDING, "a walk state that does not move is standing")
	assert_eq(_pick(M.RUN, false), P.STANDING, "so is a run state")


func test_crouch_crawl_swim_and_float_follow_the_movement_state() -> void:
	assert_eq(_pick(M.CROUCH), P.CROUCH)
	assert_eq(_pick(M.CROUCH, false), P.CROUCH, "a still crouch stays crouched")
	assert_eq(_pick(M.CROUCH, true, S.HIDDEN), P.CROUCH, "hidden in brush is still the crouch")
	assert_eq(_pick(M.CRAWL), P.CRAWL)
	assert_eq(_pick(M.SWIM), P.SWIM)
	assert_eq(_pick(M.FLOAT, false), P.FLOAT)


func test_a_dive_and_a_submerged_body_are_their_own_poses() -> void:
	assert_eq(_pick(M.DIVE), P.DIVE)
	assert_eq(_pick(M.SWIM, true, S.SUBMERGED), P.SUBMERGED)
	assert_eq(_pick(M.DIVE, false, S.SUBMERGED), P.SUBMERGED, "submerged wins over the dive state")


func test_downed_and_dragged_bodies() -> void:
	assert_eq(_pick(M.WALK, false, S.VISIBLE, true), P.DOWNED)
	assert_eq(_pick(M.SWIM, true, S.VISIBLE, true), P.DOWNED, "downed wins over every movement state")
	assert_eq(_pick(M.DRAGGED, true, S.VISIBLE, true), P.DRAGGED)


func test_dead_is_tested_before_downed() -> void:
	# The solo last stand and death both set downed (art-pass "Dead is not downed").
	assert_eq(_pick(M.WALK, false, S.VISIBLE, true, true), P.DEAD)
	assert_eq(_pick(M.DRAGGED, true, S.VISIBLE, true, true), P.DEAD, "a body being dragged when it dies")
	assert_eq(PlayerPose.animation(P.DEAD, F.RIGHT), &"dead")
	assert_eq(PlayerPose.fps(P.DEAD, false), 0.0, "dead never plays")
	assert_eq(PlayerPose.still_frame(P.DEAD), 0, "its one frame, never the downed breathing frame")


func test_each_pose_names_its_animation_per_facing() -> void:
	var expected: Dictionary = {
		P.STANDING: "idle_%s", P.WALK: "walk_%s", P.RUN: "walk_%s", P.CROUCH: "crouch_%s",
		P.CRAWL: "crouch_%s", P.SWIM: "swim_%s", P.FLOAT: "swim_%s",
	}
	var rows: Dictionary = {F.DOWN: "down", F.UP: "up", F.LEFT: "side", F.RIGHT: "side"}
	for pose: PlayerPose.Pose in expected:
		for facing: Facing.Dir in FACINGS:
			var name: String = String(expected[pose]) % rows[facing]
			assert_eq(PlayerPose.animation(pose, facing), StringName(name), "%s facing %s" % [P.keys()[pose], F.keys()[facing]])


func test_downed_dragged_and_dead_use_the_side_animation_whatever_the_facing() -> void:
	for facing: Facing.Dir in FACINGS:
		assert_eq(PlayerPose.animation(P.DOWNED, facing), &"downed")
		assert_eq(PlayerPose.animation(P.DRAGGED, facing), &"downed", "dragged draws the downed frames")
		assert_eq(PlayerPose.animation(P.DEAD, facing), &"dead")


func test_dive_and_submerged_name_no_body_animation_and_play_the_ripple() -> void:
	for pose: PlayerPose.Pose in [P.DIVE, P.SUBMERGED]:
		for facing: Facing.Dir in FACINGS:
			assert_eq(PlayerPose.animation(pose, facing), &"", "Look/Sprite is hidden")
		assert_false(PlayerPose.shows_body(pose))
		assert_true(PlayerPose.shows_ripple(pose))
		assert_false(PlayerPose.shows_shadow(pose))
		assert_false(PlayerPose.shows_water_line(pose))


func test_every_named_animation_is_in_the_template() -> void:
	var frames: SpriteFrames = load(FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "%s loads" % FRAMES_PATH)
	if frames == null:
		return
	for pose: PlayerPose.Pose in P.values():
		for facing: Facing.Dir in FACINGS:
			var name: StringName = PlayerPose.animation(pose, facing)
			if name == &"":
				continue
			assert_true(frames.has_animation(name), "%s names %s" % [P.keys()[pose], name])
	assert_false(frames.has_animation(&"dive"), "the dive ripple is fx/dive_ripple.tres, not a template animation")


func test_swim_and_float_are_drawn_12_px_lower_through_the_offset() -> void:
	for pose: PlayerPose.Pose in P.values():
		var lower: float = SWIM_DROP_PX if pose == P.SWIM or pose == P.FLOAT else 0.0
		assert_eq(PlayerPose.sprite_offset(pose), OFFSET + Vector2(0.0, lower), P.keys()[pose])


func test_the_water_line_the_shadow_and_the_ripple_per_pose() -> void:
	for pose: PlayerPose.Pose in P.values():
		var wet: bool = pose == P.SWIM or pose == P.FLOAT
		var under: bool = pose == P.DIVE or pose == P.SUBMERGED
		var label: String = P.keys()[pose]
		assert_eq(PlayerPose.shows_water_line(pose), wet, "%s water line" % label)
		assert_eq(PlayerPose.shows_shadow(pose), not wet and not under, "%s shadow" % label)
		assert_eq(PlayerPose.shows_ripple(pose), under, "%s ripple" % label)
		assert_eq(PlayerPose.shows_body(pose), not under, "%s body" % label)


func test_each_pose_gives_its_speed_or_still_frame() -> void:
	assert_eq(PlayerPose.fps(P.WALK, true), 8.0)
	assert_eq(PlayerPose.fps(P.RUN, true), 12.0, "run plays the walk frames faster")
	assert_eq(PlayerPose.fps(P.CROUCH, true), 4.0)
	assert_eq(PlayerPose.fps(P.CROUCH, false), 0.0, "a still crouch holds")
	assert_eq(PlayerPose.still_frame(P.CROUCH), 0)
	assert_eq(PlayerPose.fps(P.CRAWL, true), 2.0)
	assert_eq(PlayerPose.fps(P.SWIM, true), 4.0)
	assert_eq(PlayerPose.fps(P.FLOAT, false), 0.0, "float holds a swim frame")
	assert_eq(PlayerPose.still_frame(P.FLOAT), 0)
	assert_eq(PlayerPose.fps(P.STANDING, false), 0.0, "idle is walk frame 0")
	assert_eq(PlayerPose.still_frame(P.STANDING), 0)
	assert_eq(PlayerPose.fps(P.DOWNED, false), 1.0)
	assert_eq(PlayerPose.fps(P.DRAGGED, true), 1.0)
	for pose: PlayerPose.Pose in P.values():
		assert_lte(PlayerPose.fps(pose, true), 12.0, "%s within the 12 fps budget" % P.keys()[pose])


func test_side_frames_are_mirrored_for_left() -> void:
	for pose: PlayerPose.Pose in [P.STANDING, P.WALK, P.CROUCH, P.SWIM]:
		assert_true(PlayerPose.flip_h(pose, F.LEFT, F.LEFT))
		assert_false(PlayerPose.flip_h(pose, F.RIGHT, F.LEFT), "right is never mirrored")
		assert_false(PlayerPose.flip_h(pose, F.UP, F.LEFT), "up and down frames are not mirrored")
		assert_false(PlayerPose.flip_h(pose, F.DOWN, F.LEFT))


func test_lying_poses_keep_the_last_side_when_facing_up_or_down() -> void:
	# art-pass "Player poses": dragged faces the drag; up or down keeps the last side.
	for pose: PlayerPose.Pose in [P.DOWNED, P.DRAGGED, P.DEAD]:
		assert_true(PlayerPose.flip_h(pose, F.LEFT, F.LEFT), "%s facing left" % P.keys()[pose])
		assert_false(PlayerPose.flip_h(pose, F.RIGHT, F.RIGHT))
		assert_true(PlayerPose.flip_h(pose, F.UP, F.LEFT), "up keeps the last side, left")
		assert_true(PlayerPose.flip_h(pose, F.DOWN, F.LEFT), "down keeps it too")
		assert_false(PlayerPose.flip_h(pose, F.UP, F.RIGHT), "and right")


func test_each_pose_has_its_head_anchor_family() -> void:
	var families: Dictionary = {
		P.STANDING: &"walk", P.WALK: &"walk", P.RUN: &"walk", P.CROUCH: &"crouch", P.CRAWL: &"crouch",
		P.SWIM: &"swim", P.FLOAT: &"swim", P.DIVE: &"dive", P.SUBMERGED: &"dive",
		P.DOWNED: &"downed", P.DRAGGED: &"downed", P.DEAD: &"dead",
	}
	for pose: PlayerPose.Pose in P.values():
		assert_eq(PlayerPose.family(pose), families[pose], P.keys()[pose])
