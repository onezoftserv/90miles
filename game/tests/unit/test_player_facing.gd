extends GutTest
## art-pass "Player facing" (task 5.2), pure: `Facing` turns a player from the change of its drawn
## position over the last 0.1 s, on every peer (design.md D2). The larger axis wins and a tie faces
## sideways; below 0.05 tiles/s the last facing stays; left is the side frames mirrored; a host
## fed a client's positions in bursts does not turn in the gaps; a jump of more than 2 tiles in the
## window (landing, boarding, the throw-in; design.md P10) keeps the last facing. Every case is one
## body observed frame by frame, as a solo player's own look observes it.

const F := Facing.Dir
const TILE: float = 16.0
const FRAME_S: float = 1.0 / 60.0


# Feeds `frames` frames of steady motion at `tiles_per_s`, from `start`; returns the last position.
func _walk(facing: Facing, start: Vector2, tiles_per_s: Vector2, frames: int) -> Vector2:
	var at: Vector2 = start
	for i: int in frames:
		at += tiles_per_s * TILE * FRAME_S
		facing.observe(at, FRAME_S)
	return at


func _still(facing: Facing, at: Vector2, frames: int) -> void:
	for i: int in frames:
		facing.observe(at, FRAME_S)


func test_a_new_body_faces_down() -> void:
	var facing := Facing.new()
	assert_eq(facing.dir, F.DOWN)
	assert_false(facing.moving())


func test_moving_1_right_and_3_up_faces_up() -> void:
	var facing := Facing.new()
	_walk(facing, Vector2(100.0, 100.0), Vector2(1.0, -3.0), 30)
	assert_eq(facing.dir, F.UP, "art-pass \"Mostly up\"")
	assert_true(facing.moving())
	assert_eq(Facing.row_name(facing.dir), &"up")


func test_the_larger_axis_wins() -> void:
	var facing := Facing.new()
	_walk(facing, Vector2.ZERO, Vector2(3.0, 1.0), 30)
	assert_eq(facing.dir, F.RIGHT)
	_walk(facing, Vector2.ZERO, Vector2(-1.0, 2.0), 30)
	assert_eq(facing.dir, F.DOWN)


func test_a_tie_faces_sideways() -> void:
	var facing := Facing.new()
	_walk(facing, Vector2.ZERO, Vector2(2.0, 2.0), 30)
	assert_eq(facing.dir, F.RIGHT)
	_walk(facing, Vector2.ZERO, Vector2(-2.0, -2.0), 30)
	assert_eq(facing.dir, F.LEFT)


func test_below_the_dead_zone_the_last_facing_stays() -> void:
	var facing := Facing.new()
	var at: Vector2 = _walk(facing, Vector2.ZERO, Vector2(-2.0, 0.0), 30)
	assert_eq(facing.dir, F.LEFT)
	# 0.04 tiles/s downward: under the 0.05 tiles/s dead zone.
	_walk(facing, at, Vector2(0.0, 0.04), 60)
	assert_eq(facing.dir, F.LEFT, "a drift under the dead zone does not turn the body")
	assert_false(facing.moving(), "and it is not moving")


func test_a_teammate_who_stops_keeps_facing_left_mirrored() -> void:
	# art-pass "A teammate stops".
	var facing := Facing.new()
	var at: Vector2 = _walk(facing, Vector2(50.0, 50.0), Vector2(-2.0, 0.0), 30)
	_still(facing, at, 120)
	assert_eq(facing.dir, F.LEFT)
	assert_false(facing.moving())
	assert_eq(Facing.row_name(facing.dir), &"side", "left draws the side frames")
	assert_true(facing.flip_h(), "mirrored")
	_walk(facing, at, Vector2(2.0, 0.0), 30)
	assert_eq(facing.dir, F.RIGHT)
	assert_false(facing.flip_h(), "right is the side frames as drawn")


func test_the_last_side_is_kept_while_facing_up_or_down() -> void:
	var facing := Facing.new()
	var at: Vector2 = _walk(facing, Vector2.ZERO, Vector2(-2.0, 0.0), 30)
	_walk(facing, at, Vector2(0.0, -2.0), 30)
	assert_eq(facing.dir, F.UP)
	assert_eq(facing.last_side, F.LEFT, "a lying pose drawn now keeps the left side")


func test_a_host_fed_positions_in_bursts_keeps_facing_right() -> void:
	# art-pass "A client's intents arrive in bursts": 2 tiles/s right, the position arriving in one
	# step every 100 ms and standing still between.
	var facing := Facing.new()
	var at: Vector2 = Vector2(200.0, 200.0)
	var turned: Array[String] = []
	var since_burst_s: float = 0.0
	for i: int in 180:
		since_burst_s += FRAME_S
		if since_burst_s >= 0.1 - 0.0001:
			since_burst_s = 0.0
			at += Vector2(2.0 * TILE * 0.1, 0.0)
		facing.observe(at, FRAME_S)
		if i >= 12 and facing.dir != F.RIGHT:
			turned.append("frame %d: %s" % [i, F.keys()[facing.dir]])
	assert_eq(turned, [] as Array[String], "never turns in the gaps")
	assert_eq(facing.dir, F.RIGHT)


func test_a_jump_of_more_than_2_tiles_keeps_the_last_facing() -> void:
	# design.md P10: landing, boarding (about 4,000 px) and the throw-in teleport bodies.
	var facing := Facing.new()
	var at: Vector2 = _walk(facing, Vector2(0.0, 0.0), Vector2(2.0, 0.0), 30)
	assert_eq(facing.dir, F.RIGHT)
	at += Vector2(0.0, -4000.0)
	facing.observe(at, FRAME_S)
	_still(facing, at, 30)
	assert_eq(facing.dir, F.RIGHT, "a boarding jump north does not turn the body up")
	at += Vector2(-2.5 * TILE, 0.0)
	facing.observe(at, FRAME_S)
	_still(facing, at, 30)
	assert_eq(facing.dir, F.RIGHT, "nor does a 2.5 tile landing jump west")


func test_a_short_step_under_2_tiles_still_turns() -> void:
	var facing := Facing.new()
	var at: Vector2 = _walk(facing, Vector2.ZERO, Vector2(2.0, 0.0), 30)
	_walk(facing, at, Vector2(0.0, 4.0), 6)
	assert_eq(facing.dir, F.DOWN, "an ordinary walk of under 2 tiles in the window turns")
