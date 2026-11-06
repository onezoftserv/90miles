extends GutTest
## crafting-inventory "Fire": lights, counts as company within 5 tiles at night, burns 360 s,
## can be put out.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const STEP: float = 0.25

var body: PlayerBody


func before_each() -> void:
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.climate.phase = DataEnums.DayPhase.NIGHT


func _fire(at: Vector2) -> Fire:
	var fire := FIRE_SCENE.instantiate() as Fire
	fire.position = at
	add_child_autofree(fire)
	return fire


func _night(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		body._physics_process(STEP)


func test_a_lit_fire_stops_the_alone_at_night_drain_within_5_tiles() -> void:
	var fire := _fire(Vector2(48, 0))
	fire.light()
	body.meters.morale = 50.0
	_night(60.0)
	assert_almost_eq(body.meters.morale, 50.0, 0.001)


func test_at_6_tiles_the_drain_continues() -> void:
	var fire := _fire(Vector2(96, 0))
	fire.light()
	body.meters.morale = 50.0
	_night(60.0)
	assert_almost_eq(body.meters.morale, 45.0, 0.01)


func test_putting_it_out_restores_the_drain() -> void:
	var fire := _fire(Vector2(48, 0))
	fire.light()
	body.meters.morale = 50.0
	_night(60.0)
	fire.put_out()
	assert_false(fire.is_in_group(PlayerBody.FIRE_GROUP))
	_night(60.0)
	assert_almost_eq(body.meters.morale, 45.0, 0.01)


func test_lighting_gives_plus_5_morale_within_radius() -> void:
	body.meters.morale = 50.0
	var near := _fire(Vector2(48, 0))
	near.light()
	assert_almost_eq(body.meters.morale, 55.0, 0.001)
	body.meters.morale = 50.0
	var far := _fire(Vector2(96, 0))
	far.light()
	assert_almost_eq(body.meters.morale, 50.0, 0.001)


func test_burns_out_after_360_s() -> void:
	var fire := _fire(Vector2.ZERO)
	fire.light()
	fire.advance(359.9)
	assert_true(fire.lit)
	fire.advance(0.2)
	assert_false(fire.lit)
	assert_false(fire.is_in_group(PlayerBody.FIRE_GROUP))


func test_a_player_puts_it_out_with_a_2_second_interaction() -> void:
	var fire := _fire(Vector2(8, 0))
	fire.light()
	assert_eq(fire.interactable.hold_time_s, 2.0)
	fire.interactable.use(body)
	assert_false(fire.lit)
