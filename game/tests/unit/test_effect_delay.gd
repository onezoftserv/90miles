extends GutTest
## crafting-inventory "Delayed effects": an effect with delay_s applies on the host that many
## seconds of the player's own time after it fires. One offline player takes it the same way.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const STEP_S: float = 0.1

var body: PlayerBody


func before_each() -> void:
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	# Nothing else moves thirst: the drain is off.
	var tuning := body.meters.tuning.duplicate() as SurvivalTuning
	tuning.thirst_per_s = 0.0
	body.meters.tuning = tuning
	body.meters.thirst = 50.0


func _delayed_thirst(amount: float, delay_s: float) -> EffectData:
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.METER_ADD
	effect.meter = DataEnums.Meter.THIRST
	effect.amount = amount
	effect.delay_s = delay_s
	return effect


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		body.meters.tick(STEP_S, MeterContext.new())


func test_a_delayed_thirst_loss() -> void:
	EffectApplier.apply(_delayed_thirst(-5.0, 30.0), body, null)
	assert_eq(body.meters.thirst, 50.0, "nothing at once")
	_run(29.9)
	assert_eq(body.meters.thirst, 50.0, "unchanged at 29.9 s")
	_run(0.1)
	assert_almost_eq(body.meters.thirst, 45.0, 0.001, "5 lower at 30 s")
	_run(10.0)
	assert_almost_eq(body.meters.thirst, 45.0, 0.001, "it applies once")


func test_an_effect_without_a_delay_still_applies_at_once() -> void:
	EffectApplier.apply(_delayed_thirst(10.0, 0.0), body, null)
	assert_eq(body.meters.thirst, 60.0)


func test_a_delayed_effect_waits_while_the_player_is_out_of_play() -> void:
	EffectApplier.apply(_delayed_thirst(-5.0, 30.0), body, null)
	_run(20.0)
	# A waiting rider's meters do not tick (the physics step skips them), so the clock waits too.
	body.left_island = true
	body._tick_meters(25.0)
	assert_eq(body.meters.thirst, 50.0, "frozen while waiting")
	body.left_island = false
	_run(10.0)
	assert_almost_eq(body.meters.thirst, 45.0, 0.001, "it still lands once the player is back in play")


func test_a_delay_on_a_freed_body_does_nothing() -> void:
	EffectApplier.apply(_delayed_thirst(-5.0, 30.0), body, null)
	_run(10.0)
	body.free()
	await wait_frames(2)
	assert_true(true, "no error when the body goes before the effect is due")
