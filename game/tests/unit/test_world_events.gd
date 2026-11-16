extends GutTest
## guardacostas-stealth, group 5 (design.md decision 8): the world event bus is a node of the
## session, not an autoload. A solo player (offline, no host or port) using the noise fixture item
## puts one noise event on it; a place's noise multiplier scales a noise through the
## CreatureWorld.noise_multiplier_at seam; lighting a fire raises one smoke event and
## smoke_sources() lists it until it goes out. Blood is not built: no creature emits it yet.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const FIXTURES: String = "res://tests/fixtures/content"
const TOLERANCE: float = 0.000001

var session: CoopSession
var body: PlayerBody
var heard: Array = []
var smoke: Array = []


## A world whose every place doubles a noise (a cave, say).
class DoubleWorld extends CreatureWorld:
	func noise_multiplier_at(_cell: Vector2i) -> float:
		return 2.0


func before_each() -> void:
	heard = []
	smoke = []
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	body = session.body(session.multiplayer.get_unique_id())
	body.global_position = Vector2(100.0, 60.0)
	var bus := _bus()
	bus.noise_made.connect(func(at: Vector2, radius: float, source: StringName) -> void: heard.append([at, radius, source]))
	bus.smoke_rose.connect(func(at: Vector2, fire: Node2D) -> void: smoke.append([at, fire]))


func _bus() -> WorldEvents:
	return session.get_node(^"WorldEvents") as WorldEvents


func _noisy_pot() -> void:
	body.inventory.catalog = ContentCatalog.new(FIXTURES)
	assert_eq(body.inventory.add(&"noise_test", 1), 1)


func _fire(at: Vector2) -> Fire:
	var fire := FIRE_SCENE.instantiate() as Fire
	fire.position = at
	session.add_child(fire)
	return fire


func test_a_solo_player_using_the_noise_item_puts_one_noise_on_the_bus() -> void:
	_noisy_pot()
	assert_true(ItemUser.use(body, 0, 0))
	assert_eq(heard.size(), 1)
	assert_eq(heard[0][0], body.global_position)
	assert_almost_eq(heard[0][1] as float, 15.0, TOLERANCE)
	assert_eq(heard[0][2], &"effect", "no ref_id on the effect: the generic source")


func test_the_last_noise_can_be_read_without_a_signal() -> void:
	_noisy_pot()
	ItemUser.use(body, 0, 0)
	assert_eq(_bus().last_noise.radius_tiles, 15.0)
	assert_eq(_bus().noise_count, 1)


func test_a_place_that_doubles_noise_turns_radius_10_into_20() -> void:
	var world := DoubleWorld.new()
	_bus().world = world
	_bus().make_noise(Vector2(50.0, 50.0), 10.0, &"test")
	assert_eq(heard.size(), 1)
	assert_almost_eq(heard[0][1] as float, 20.0, TOLERANCE)


func test_without_a_world_a_noise_keeps_its_radius() -> void:
	_bus().make_noise(Vector2(50.0, 50.0), 10.0, &"test")
	assert_almost_eq(heard[0][1] as float, 10.0, TOLERANCE)
	assert_almost_eq(CreatureWorld.new().noise_multiplier_at(Vector2i.ZERO), 1.0, TOLERANCE)


func test_lighting_a_fire_raises_one_smoke_event_and_lists_it_until_it_goes_out() -> void:
	var fire := _fire(Vector2(160.0, 80.0))
	assert_eq(_bus().smoke_sources().size(), 0)
	fire.light()
	assert_eq(smoke.size(), 1)
	assert_eq(smoke[0][1], fire)
	assert_eq(smoke[0][0], fire.global_position)
	assert_eq(_bus().smoke_sources(), [fire] as Array[Node2D])
	fire.put_out()
	assert_eq(_bus().smoke_sources().size(), 0)
	assert_eq(smoke.size(), 1, "putting it out raises nothing")


func test_a_fire_outside_a_session_lights_without_an_event() -> void:
	var loose := FIRE_SCENE.instantiate() as Fire
	add_child_autofree(loose)
	loose.light()
	assert_true(loose.lit)
	assert_eq(smoke.size(), 0)


func test_the_smoke_effect_raises_smoke_at_the_actor() -> void:
	var effect := EffectData.new()
	effect.kind = EffectData.Kind.SMOKE
	EffectApplier.apply(effect, body, null)
	assert_eq(smoke.size(), 1)
	assert_eq(smoke[0][0], body.global_position)


func test_the_bus_is_a_session_node_and_not_an_autoload() -> void:
	assert_eq(_bus().get_parent(), session)
	assert_eq(_bus().name, &"WorldEvents")
	assert_false(ProjectSettings.has_setting("autoload/WorldEvents"))
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = property["name"]
		if key.begins_with("autoload/"):
			assert_false(String(ProjectSettings.get_setting(key)).contains("world_events"), key)
