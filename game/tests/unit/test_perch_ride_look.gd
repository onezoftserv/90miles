extends GutTest
## creature-perch-ride "Perched creature on every peer", offline: a perched galleguito is drawn on
## its rider's body (not at its synced position), its feet on the rider's head, over the rider,
## facing the way the rider's look faces. One offline player.

const FIXTURES: String = "res://tests/fixtures/content"
const STEP_S: float = 0.1

var riders: CrossingCreatures
var gull: Creature
var body: PlayerBody


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var session := CrossingRig.make_session(self, 1)
	session.creature_catalog = ContentCatalog.new(FIXTURES)
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 200.0)
	body = crossing.body_of(1)
	riders = CrossingCreatures.attach(crossing, DataEnums.ChainFamily.FINAL, DataEnums.DistanceBand.COAST)
	gull = riders.creatures()[0]
	var waited: float = 0.0
	while gull.state_name() != &"PERCH" and waited < 30.0:
		crossing.advance(STEP_S)
		gull.advance(STEP_S)
		waited += STEP_S


func after_each() -> void:
	NetManager.leave()


func _look() -> CreatureLook:
	return gull.get_node(^"Look") as CreatureLook


func _sprite() -> AnimatedSprite2D:
	return gull.get_node(^"Look/Sprite") as AnimatedSprite2D


func _rider_look() -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _feet_y(sprite: AnimatedSprite2D) -> float:
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return sprite.global_position.y + frame.get_size().y / 2.0


func test_the_solo_players_gull_is_drawn_on_their_head_and_over_them() -> void:
	assert_eq(gull.perch_peer, 1)
	_look().step(0.0)
	assert_true(_sprite().visible)
	assert_eq(_look().global_position, body.global_position + Vector2(0.0, CreatureLook.PERCH_SORT_PX), "on the rider, 1 px south so it sorts over them")
	var head_y: float = body.global_position.y + (body.get_node(^"BodyLook") as BodyLook).head_y()
	assert_almost_eq(_feet_y(_sprite()), head_y, 0.01, "its feet on the rider's head")
	assert_eq(_sprite().global_position.x, body.global_position.x, "centred on the rider")
	assert_false((gull.get_node(^"Look/Shadow") as DropShadow).visible, "no shadow of its own up there")
	assert_true(DrawOrder.drawn_after(_sprite(), body), "drawn over the rider")


func test_it_follows_the_drawn_body_not_its_synced_position() -> void:
	var synced := gull.position
	body.global_position += Vector2(5.0, 0.0)
	_look().step(0.0)
	assert_eq(gull.position, synced, "the synced position has not caught up")
	assert_eq(_look().global_position, body.global_position + Vector2(0.0, CreatureLook.PERCH_SORT_PX), "the look is already on the body")


func test_it_turns_with_its_rider() -> void:
	_rider_look().facing.dir = Facing.Dir.LEFT
	_look().step(0.0)
	var left: bool = _sprite().flip_h
	var left_animation: StringName = _sprite().animation
	_rider_look().facing.dir = Facing.Dir.RIGHT
	_look().step(0.0)
	assert_ne(_sprite().flip_h, left, "mirrored when the rider turns from left to right")
	assert_eq(_sprite().animation, left_animation, "the same side frames")


func test_off_the_head_it_is_drawn_where_it_is() -> void:
	gull.shoo(body)
	assert_eq(gull.perch_peer, 0)
	_look().step(0.0)
	assert_eq(_look().position.x, 0.0, "back on its own position")


func test_it_is_placed_after_the_players_are_moved_and_turned_each_frame() -> void:
	# A client moves a remote player's drawn body (PlayerNet) and turns its look (PlayerLook) in their
	# _process; the gull's look runs after both, so it never trails its rider by a frame.
	var after: int = _look().process_priority
	assert_gt(after, (body.get_node(^"PlayerNet") as Node).process_priority)
	assert_gt(after, _rider_look().process_priority)
