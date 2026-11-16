extends GutTest
## survival-meters "Bleeding drains health" and "Bleeding stops on its own" with exactly 1 player,
## offline, through a real body: a shark's strike, then the drain; the "Sangrando" tag going when
## the time is up; a waiting rider's frozen time; and a lone swimmer outlasting a wound with no
## sábila at all (bleeding-and-sabila design, "Solo worst case").

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/meters_hud.tscn")
const BLEEDING := DataEnums.Status.BLEEDING
const STEP_S: float = 0.5

var session: CoopSession
var body: PlayerBody


func before_each() -> void:
	NetManager.start_solo()
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false


func after_each() -> void:
	NetManager.leave()


func _shark() -> CreatureData:
	return GameState.content.get_entry(&"creatures", &"reef_shark") as CreatureData


# The host's own meter step for the body, as its physics frame runs it.
func _tick(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		body._tick_meters(STEP_S)


func test_solo_a_sharks_strike_takes_25_then_the_bleeding_drains() -> void:
	CreatureWorld.new().strike(body, _shark())
	assert_eq(body.meters.health, 75.0, "the strike at once")
	assert_true(body.meters.has_status(BLEEDING))
	_tick(10.0)
	assert_almost_eq(body.meters.health, 74.0, 0.01, "1 more in 10 s")
	assert_true(body.meters.solo, "a 1-player run")


func test_solo_the_sangrando_tag_goes_when_the_bleeding_ends() -> void:
	var hud := HUD_SCENE.instantiate() as MetersHud
	add_child_autofree(hud)
	hud.bind(body.meters)
	CreatureWorld.new().strike(body, _shark())
	assert_true(hud.bleeding_tag().visible)
	_tick(119.5)
	assert_true(hud.bleeding_tag().visible, "still bleeding at 119.5 s")
	_tick(0.5)
	assert_false(hud.bleeding_tag().visible, "the tag hides at 120 s")
	assert_almost_eq(body.meters.health, 63.0, 0.01, "75, less 12")


func test_solo_a_waiting_rider_keeps_the_time_left() -> void:
	CreatureWorld.new().strike(body, _shark())
	_tick(30.0)
	assert_almost_eq(body.meters.status_time_left(BLEEDING), 90.0, 0.001)
	var health: float = body.meters.health
	IslandArrival.hold(body)
	_tick(60.0)
	assert_almost_eq(body.meters.status_time_left(BLEEDING), 90.0, 0.001, "frozen out of play")
	assert_eq(body.meters.health, health)
	IslandArrival.land(body, Vector2(64.0, 64.0), session.terrain)
	_tick(89.5)
	assert_true(body.meters.has_status(BLEEDING))
	_tick(0.5)
	assert_false(body.meters.has_status(BLEEDING), "the rest of the 120 s, once back in play")


func test_solo_swimmer_at_30_outlasts_a_wound_with_no_sabila() -> void:
	var rig := CreatureRig.make(self)
	var swimmer := rig.player(Vector2i(16, 15))
	swimmer.meters.solo = true
	swimmer.meters.health = 30.0
	swimmer.meters.energy = 19.0
	var shark := rig.shark(Vector2i(19, 15))
	rig.run(6.1)
	assert_eq(swimmer.meters.health, 5.0, "struck once")
	assert_true(swimmer.meters.has_status(BLEEDING))
	# The swimmer reaches the shallows, out of the shark's water, and waits there with no cure.
	swimmer.global_position = CreatureRig.center(Vector2i(CreatureRig.BEACH_COLUMNS, 15))
	swimmer.meters.energy = 100.0
	for i: int in roundi(125.0 / STEP_S):
		swimmer.meters.tick(STEP_S, MeterContext.new())
		rig.run(STEP_S)
	assert_false(swimmer.meters.dead)
	assert_false(swimmer.meters.last_stand)
	assert_eq(swimmer.meters.health, 1.0, "bleeding stopped at the last point")
	assert_false(swimmer.meters.has_status(BLEEDING), "and ended on its own")
	# Back in deep water at full energy, no longer bleeding: the shark circles and leaves.
	swimmer.global_position = CreatureRig.center(Vector2i(16, 15))
	rig.run(15.0)
	assert_eq(swimmer.meters.health, 1.0, "no longer a shark target")
	assert_false(swimmer.meters.dead)
	assert_true(is_instance_valid(shark))
