extends GutTest
## island-pressure task 4.2 (survival-meters "Health and downed state", "Solo last stand", "Free revive";
## endings-progression "Solo last stand from Experiencia"): a player with no other living player gets a
## 12 s last stand on land plus their downed-timer bonuses, and the bonuses alone at sea. 1 player,
## offline, then a host and a client for the last one alive.

const STEP_S: float = 0.1
## A step the thirst drain (2 health a second) divides exactly, so health reaches 0 on a tick and not a
## float crumb later.
const DRY_STEP_S: float = 0.25
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")

var meters: SurvivalMeters
var land: MeterContext
var sea: MeterContext
var net: NetHarness = null


func before_each() -> void:
	meters = autofree(SurvivalMeters.new()) as SurvivalMeters
	meters.solo = true
	land = MeterContext.new()
	sea = MeterContext.new()
	sea.at_sea = true


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null
	WeatherManager.stop()
	NetManager.leave()


func _tick(context: MeterContext, seconds: float, step: float = STEP_S) -> void:
	for i: int in roundi(seconds / step):
		meters.tick(step, context)


# Health to 0 in `context`: the tick first records where the player is.
func _hit_zero(context: MeterContext) -> void:
	meters.tick(0.0, context)
	meters.harm(meters.health, &"other")


func test_the_base_is_data() -> void:
	assert_eq(meters.tuning.solo_last_stand_s, 12.0)


# "Solo": not downed but in a last stand, alive after 11.9 s and dead after 12 s.
func test_solo_on_land_on_run_1() -> void:
	_hit_zero(land)
	assert_true(meters.last_stand)
	assert_false(meters.downed)
	_tick(land, 11.9)
	assert_false(meters.dead, "alive after 11.9 s")
	_tick(land, 0.1)
	assert_true(meters.dead, "dead after 12 s")


func test_last_stand_with_experiencia() -> void:
	meters.downed_bonus_s = 15.0
	_hit_zero(land)
	_tick(land, 26.0)
	assert_false(meters.dead, "alive after 26 s")
	_tick(land, 1.0)
	assert_true(meters.dead, "dead after 27 s")


func test_run_1_at_sea_dies_at_once() -> void:
	_hit_zero(sea)
	assert_true(meters.dead, "no last stand at sea")
	assert_false(meters.last_stand)


# endings-progression "Run 1 solo" and "Eased solo".
func test_the_windows_on_land_and_at_sea() -> void:
	meters.downed_bonus_s = 30.0
	_hit_zero(land)
	assert_almost_eq(meters.downed_time_left_s, 42.0, 0.001, "eased: 42 s on land")
	var rider := autofree(SurvivalMeters.new()) as SurvivalMeters
	rider.solo = true
	rider.downed_bonus_s = 30.0
	rider.tick(0.0, sea)
	rider.harm(rider.health, &"other")
	assert_almost_eq(rider.downed_time_left_s, 30.0, 0.001, "eased: 30 s at sea")


func test_the_medalla_then_a_12_s_last_stand() -> void:
	meters.free_revives = 1
	_hit_zero(land)
	assert_eq(meters.health, 30.0, "the Medalla stands them up")
	_hit_zero(land)
	assert_true(meters.last_stand, "the second time, a last stand")
	assert_almost_eq(meters.downed_time_left_s, 12.0, 0.001)


func test_a_solo_player_dies_of_thirst_after_13_s() -> void:
	meters.thirst = 0.0
	meters.health = 2.0
	_tick(land, 12.75, DRY_STEP_S)
	assert_false(meters.dead, "alive at 12.75 s")
	_tick(land, 0.25, DRY_STEP_S)
	assert_true(meters.dead, "dead at 13 s")
	assert_eq(meters.death_cause, &"thirst")


func test_poison_from_10_health() -> void:
	meters.health = 10.0
	meters.add_over_time(DataEnums.Meter.HEALTH, -20.0, 30.0)
	_tick(land, 16.0)
	assert_true(meters.last_stand, "in a last stand after 16 s")
	_tick(land, 11.0)
	assert_true(meters.dead, "dead after 27 s")
	assert_eq(meters.death_cause, &"other")


# "Run 1 alone and dry": a real body on the sandbar, offline, with a coconut and the knife.
func test_run_1_alone_and_dry() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.with_creatures = false
	island.furnish(session)
	session.start()
	var body := session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.inventory.add(&"coco", 1)
	body.inventory.add(&"knife", 1)
	body.meters.thirst = 0.0
	body.meters.health = 2.0
	for i: int in 4:
		body._tick_meters(DRY_STEP_S)
	assert_true(body.meters.last_stand, "1 s dry: a last stand, not death")
	var slot: int = -1
	for i: int in body.inventory.slots.size():
		if body.inventory.slots[i].item_id == &"coco":
			slot = i
	var revive_use: int = 1
	assert_true(ItemUser.revives(body, slot, revive_use), "the coconut's second use stands a player up")
	assert_true(session.use_for(CoopSession.HOST_ID, slot, revive_use, 0), "they drink it on themselves")
	assert_false(body.meters.last_stand)
	assert_eq(body.meters.health, 30.0)
	assert_almost_eq(body.meters.thirst, 15.0, 0.01)


# "Last one alive", a host and a client: the client's player is dead, so the host's player's 0 health
# is a 12 s last stand, which the client sees too. In-process both sessions share one scene tree, so the
# host's player would count the client session's copies as living teammates: the test sets the flag the
# host derives (PlayerBody._has_living_teammate) where a second process would derive it.
func test_the_last_one_alive_gets_12_s_on_both_peers() -> void:
	net = NetHarness.new(self)
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var me: int = net.peer_id(client)
	host.body(me).meters._die(&"other")
	var dead := func() -> bool: return client.body(me).meters.dead
	assert_true(await wait_until(dead, 5.0), "the client sees its player dead")
	host.body(CoopSession.HOST_ID).meters.solo = true
	host.body(CoopSession.HOST_ID).meters.harm(200.0, &"other")
	assert_true(host.body(CoopSession.HOST_ID).meters.last_stand, "a last stand, not downed")
	assert_almost_eq(host.body(CoopSession.HOST_ID).meters.downed_time_left_s, 12.0, 0.1)
	var seen := func() -> bool: return client.body(CoopSession.HOST_ID).meters.last_stand
	assert_true(await wait_until(seen, 5.0), "the client sees the host's player in a last stand")
	assert_lte(client.body(CoopSession.HOST_ID).meters.downed_time_left_s, 12.0)
	assert_gt(client.body(CoopSession.HOST_ID).meters.downed_time_left_s, 9.0)
