extends GutTest
## inventory-hud "Hold ring" with exactly 1 player, offline, on the sandbar: a 10 px ring left of
## the prompt's key fills from the press until the target's hold time has passed, on the same
## frames as the host's hold; until release the prompt and ring stay on the target the press
## started on, and empty once it is beyond reach and the slack. Instant interactions show no
## ring. The body and the prompt are stepped together by hand in 0.1 s steps, so the times are
## exact.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const STEP_S: float = 0.1
const TILE: float = 16.0

var island: SandbarIsland
var session: CoopSession
var hud: RunHud
var palm: Palm


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _run() -> PlayerBody:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	island.place_pickups(session)
	var body := session.body(1)
	body.player_input.enabled = false
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, 1, true)
	palm = island.get_node("Palms").get_child(0) as Palm
	palm.coconuts = 2
	body.global_position = palm.global_position + Vector2(4.0, 0.0)
	hud.prompt.tick(STEP_S)
	return body


func _press(body: PlayerBody, held: bool) -> void:
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, held)


func _step(body: PlayerBody, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		body.advance(STEP_S)
		hud.prompt.tick(STEP_S)


func test_a_2_s_climb_fills_the_ring_half_at_1_s_and_full_at_2_s() -> void:
	var body := _run()
	assert_eq(palm.interactable.hold_time_s, 2.0)
	assert_true(hud.prompt.ring.visible, "a timed hold has a ring")
	assert_eq(hud.prompt.ring.value, 0.0, "empty before the press")
	assert_eq(hud.prompt.ring.size, Vector2(10.0, 10.0))
	_press(body, true)
	_step(body, 1.0)
	assert_almost_eq(hud.prompt.ring.value, 0.5, 0.001, "half full at 1 s")
	assert_eq(body.inventory.count_id(&"coco"), 0)
	_step(body, 1.0)
	assert_almost_eq(hud.prompt.ring.value, 1.0, 0.001, "full at 2 s")
	assert_eq(body.inventory.count_id(&"coco"), 1, "the coconut arrives with it")
	_step(body, 0.5)
	assert_almost_eq(hud.prompt.ring.value, 1.0, 0.001, "full until release")
	assert_eq(body.inventory.count_id(&"coco"), 1, "one climb per press")


func test_letting_go_empties_it_and_takes_nothing() -> void:
	var body := _run()
	_press(body, true)
	_step(body, 1.0)
	assert_almost_eq(hud.prompt.ring.value, 0.5, 0.001)
	_press(body, false)
	_step(body, STEP_S)
	assert_eq(hud.prompt.ring.value, 0.0, "empty on release")
	_step(body, 2.0)
	assert_eq(body.inventory.count_id(&"coco"), 0, "no coconut was taken")
	assert_eq(palm.coconuts, 2)


func test_walking_beyond_18_px_resets_it() -> void:
	var body := _run()
	_press(body, true)
	_step(body, 1.0)
	body.global_position = palm.global_position + Vector2(19.0, 0.0)
	_step(body, STEP_S)
	assert_eq(hud.prompt.ring.value, 0.0, "beyond reach and the slack")
	assert_null(hud.prompt.target, "nothing is locked while the press is still held")
	body.global_position = palm.global_position + Vector2(4.0, 0.0)
	_step(body, 2.0)
	assert_eq(body.inventory.count_id(&"coco"), 0, "the host dropped the climb too")
	assert_eq(hud.prompt.ring.value, 0.0, "walking back in starts nothing without a new press")


func test_a_pickup_landing_nearer_mid_climb_leaves_the_prompt_on_the_palm() -> void:
	var body := _run()
	_press(body, true)
	_step(body, 1.0)
	var coconut := session.spawn_pickup(&"coco", 1, body.global_position)
	_step(body, 0.5)
	assert_same(hud.prompt.target, palm.interactable, "the prompt stays on the palm")
	assert_eq(hud.prompt.lines()[0], "[E] Trepar Mata de coco")
	assert_almost_eq(hud.prompt.ring.value, 0.75, 0.001, "and its ring keeps filling")
	_step(body, 0.5)
	assert_eq(body.inventory.count_id(&"coco"), 1, "the palm's coconut arrives at 2 s")
	assert_true(is_instance_valid(coconut) and not coconut.is_queued_for_deletion(), "the pick-up stays on the ground")
	_press(body, false)
	_step(body, STEP_S)
	assert_same(hud.prompt.target, coconut.interactable, "released, the prompt picks again: the pick-up is nearest")


func test_an_instant_pickup_shows_no_ring() -> void:
	var body := _run()
	var wood := session.spawn_pickup(&"driftwood", 1, body.global_position + Vector2(0.0, 2.0))
	hud.prompt.tick(STEP_S)
	assert_same(hud.prompt.target, wood.interactable)
	assert_false(hud.prompt.ring.visible, "no ring before the press")
	_press(body, true)
	body.advance(STEP_S)
	hud.prompt.tick(STEP_S)
	assert_false(hud.prompt.ring.visible, "nor during it")
	assert_eq(body.inventory.count_id(&"driftwood"), 1)
