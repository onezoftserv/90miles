extends GutTest
## survival-meters "Hurt cue on the body" (damage-feedback design D4), with exactly 1 player,
## offline: on a hit the body is drawn white for one frame, then blinks at 10 Hz until 0.6 s; with
## "Reducir destellos" it is a steady red tint instead; a drain or a dead body shows nothing. The
## look is stepped by hand, so no frame runs on its own.

const PLAYER_PATH: String = "res://scenes/player/player.tscn"
const FRAME: float = 1.0 / 60.0

var blink: HurtBlink


func before_each() -> void:
	NetManager.start_solo()
	HurtCues.reduce_flashes = false
	blink = HurtBlink.new(0.6, 10.0)


func after_each() -> void:
	HurtCues.reduce_flashes = false
	NetManager.leave()


# --- the pure blink ------------------------------------------------------------------------------

func test_a_blink_is_white_first_then_hides_at_10_hz_until_0_6_s() -> void:
	assert_false(blink.active(), "nothing before a hit")
	blink.start()
	assert_true(blink.white(false), "white on the first frame")
	assert_false(blink.hidden(false))
	blink.advance(FRAME)
	assert_false(blink.white(false))
	var hidden_frames: Array[int] = []
	var frame: int = 1
	while blink.active():
		if blink.hidden(false):
			hidden_frames.append(frame)
		blink.advance(FRAME)
		frame += 1
	assert_eq(frame, 36, "0.6 s at 60 frames a second")
	assert_eq(hidden_frames.slice(0, 5), [1, 2, 6, 7, 8] as Array[int], "hidden right after the white frame, shown for 0.05 s, hidden again")
	assert_false(blink.white(false) or blink.hidden(false), "clear after 0.6 s")


func test_reduce_flashes_tints_instead() -> void:
	blink.start()
	assert_false(blink.white(true), "never white")
	assert_true(blink.tinted(true))
	for i: int in 36:
		assert_false(blink.hidden(true), "never hidden")
		assert_true(blink.tinted(true), "tinted for the whole 0.6 s")
		blink.advance(FRAME)
	assert_false(blink.tinted(true), "and clear after")
	blink.start()
	assert_false(blink.tinted(false), "no tint with flashes allowed")


func test_a_new_hit_restarts_the_blink() -> void:
	blink.start()
	for i: int in 30:
		blink.advance(FRAME)
	blink.start()
	assert_true(blink.white(false))
	for i: int in 30:
		blink.advance(FRAME)
	assert_true(blink.active(), "0.6 s from the second hit")


# --- on a solo body ------------------------------------------------------------------------------

func _spawn() -> PlayerBody:
	var body := (load(PLAYER_PATH) as PackedScene).instantiate() as PlayerBody
	body.local_player = true
	body.position = Vector2(100.0, 100.0)
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func _look(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _param(look: PlayerLook, uniform: StringName) -> Variant:
	return (look.sprite.material as ShaderMaterial).get_shader_parameter(uniform)


func _tint_on(look: PlayerLook) -> bool:
	var tint: Variant = _param(look, &"hurt_tint")
	return tint is Color and (tint as Color).a > 0.0


func test_a_crab_pinch_blinks_a_solo_body() -> void:
	var body := _spawn()
	var look := _look(body)
	look.step(FRAME)
	body.meters.harm(5.0, &"land_crab")
	look.step(FRAME)
	assert_true(_param(look, &"hurt_white"), "white on the first frame after the pinch")
	look.step(FRAME)
	assert_false(_param(look, &"hurt_white"))
	assert_true(_param(look, &"hurt_hidden"), "then it blinks")
	var hidden_seen: int = 0
	var shown_seen: int = 0
	for i: int in 34:
		look.step(FRAME)
		if _param(look, &"hurt_hidden"):
			hidden_seen += 1
		else:
			shown_seen += 1
	assert_gt(hidden_seen, 10)
	assert_gt(shown_seen, 10)
	look.step(FRAME)
	assert_false(_param(look, &"hurt_white"))
	assert_false(_param(look, &"hurt_hidden"), "drawn as before 0.6 s after the pinch")
	assert_false(_tint_on(look))


func test_thirst_at_0_never_blinks() -> void:
	var body := _spawn()
	var look := _look(body)
	look.step(FRAME)
	body.meters.thirst = 0.0
	var rest := MeterContext.new()
	var health_before: float = body.meters.health
	for i: int in 180:
		body.meters.tick(FRAME, rest)
		look.step(FRAME)
		assert_false(_param(look, &"hurt_white"), "frame %d" % i)
		assert_false(_param(look, &"hurt_hidden"), "frame %d" % i)
	assert_lt(body.meters.health, health_before - 5.0, "health did drain")


func test_a_dead_body_never_blinks() -> void:
	var body := _spawn()
	var look := _look(body)
	body.meters.solo = true
	look.step(FRAME)
	body.meters.dead = true
	body.meters.health = 40.0
	look.step(FRAME)
	assert_false(_param(look, &"hurt_white"))
	assert_false(_param(look, &"hurt_hidden"))


func test_reduce_flashes_tints_the_body() -> void:
	HurtCues.reduce_flashes = true
	var body := _spawn()
	var look := _look(body)
	look.step(FRAME)
	body.meters.harm(25.0, &"reef_shark")
	for i: int in 36:
		look.step(FRAME)
		assert_false(_param(look, &"hurt_white"), "never white")
		assert_false(_param(look, &"hurt_hidden"), "never hidden")
		assert_true(_tint_on(look), "tinted red, frame %d" % i)
	look.step(FRAME)
	assert_false(_tint_on(look), "clear after 0.6 s")
