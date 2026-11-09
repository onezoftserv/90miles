extends GutTest
## survival-meters "Cause of death" and "Cause ids", with exactly 1 player unless a test says
## otherwise: health losses name their cause, a downed player or a last stand keeps the cause that
## put them down, a free revive records nothing, and the cause reaches clients before `dead`.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SHARK: StringName = &"reef_shark"
const CRAB: StringName = &"land_crab"


func _meters() -> SurvivalMeters:
	var meters := SurvivalMeters.new()
	add_child_autofree(meters)
	return meters


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	return body


func _creature(id: StringName) -> CreatureData:
	return GameState.content.get_entry(&"creatures", id) as CreatureData


func test_a_solo_player_dies_of_thirst() -> void:
	var meters := _meters()
	meters.solo = true
	meters.thirst = 0.0
	meters.health = 2.0
	meters.tick(1.0, MeterContext.new())
	assert_true(meters.dead)
	assert_eq(meters.death_cause, &"thirst")


func test_a_co_op_player_downed_by_a_shark_dies_of_the_shark() -> void:
	var meters := _meters()
	meters.solo = false
	meters.harm(100.0, SHARK)
	assert_true(meters.downed)
	assert_false(meters.dead)
	assert_eq(meters.death_cause, &"", "no cause until they die")
	meters.thirst = 0.0
	meters.tick(89.0, MeterContext.new())
	assert_false(meters.dead)
	meters.tick(1.0, MeterContext.new())
	assert_true(meters.dead)
	assert_eq(meters.death_cause, SHARK, "the dry drain while down does not change it")


func test_a_revive_forgets_the_downing_cause() -> void:
	var meters := _meters()
	meters.harm(100.0, SHARK)
	assert_true(meters.revive())
	assert_eq(meters.health, 30.0)
	meters.solo = true
	meters.thirst = 0.0
	meters.tick(14.0, MeterContext.new())
	assert_false(meters.dead)
	assert_almost_eq(meters.health, 2.0, 0.001)
	meters.tick(1.0, MeterContext.new())
	assert_true(meters.dead)
	assert_eq(meters.death_cause, &"thirst")


func test_a_solo_last_stand_keeps_the_crab() -> void:
	var meters := _meters()
	meters.solo = true
	meters.downed_bonus_s = 15.0
	meters.harm(100.0, CRAB)
	assert_true(meters.last_stand)
	meters.tick(14.0, MeterContext.new())
	assert_false(meters.dead)
	meters.tick(1.0, MeterContext.new())
	assert_true(meters.dead)
	assert_eq(meters.death_cause, CRAB)


func test_poison_is_other() -> void:
	var meters := _meters()
	meters.solo = true
	meters.health = 10.0
	meters.add_over_time(DataEnums.Meter.HEALTH, -20.0, 30.0)
	for i: int in 14:
		meters.tick(1.0, MeterContext.new())
	assert_false(meters.dead)
	meters.tick(1.0, MeterContext.new())
	assert_true(meters.dead)
	assert_eq(meters.death_cause, &"other")


func test_the_medalla_records_no_cause() -> void:
	var meters := _meters()
	meters.solo = true
	meters.free_revives = 1
	meters.harm(100.0, SHARK)
	assert_eq(meters.health, 30.0)
	assert_false(meters.dead)
	assert_eq(meters.death_cause, &"")
	assert_eq(meters.free_revives, 0)


func test_a_plain_health_loss_is_other() -> void:
	var meters := _meters()
	meters.solo = true
	meters.add(DataEnums.Meter.HEALTH, -100.0)
	assert_true(meters.dead)
	assert_eq(meters.death_cause, &"other")


func test_hunger_heat_energy_and_morale_never_kill() -> void:
	var meters := _meters()
	meters.solo = true
	meters.hunger = 0.0
	meters.energy = 0.0
	meters.morale = 0.0
	meters.heat = 100.0
	meters.thirst = 100.0
	for i: int in 300:
		meters.tick(1.0, MeterContext.new())
	assert_false(meters.dead)
	assert_eq(meters.health, 100.0)
	assert_eq(meters.death_cause, &"")


func test_a_crab_pinch_names_the_crab() -> void:
	var body := _body()
	body.meters.solo = true
	body.meters.health = 5.0
	CreatureWorld.new().pinch(body, _creature(CRAB))
	assert_true(body.meters.dead)
	assert_eq(body.meters.death_cause, CRAB)


func test_a_shark_strike_names_the_shark() -> void:
	var body := _body()
	body.meters.solo = true
	body.meters.health = 25.0
	CreatureWorld.new().strike(body, _creature(SHARK))
	assert_true(body.meters.dead)
	assert_eq(body.meters.death_cause, SHARK)
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING))


func test_drowning_in_a_crossing() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 60.0)
	crossing.throw_in(1)
	var rider := crossing.body_of(1)
	rider.meters.solo = true
	rider.meters.energy = 0.0
	CrossingRig.run(crossing, 9.9)
	assert_false(rider.meters.dead, "still alive after 9.9 s")
	assert_almost_eq(rider.meters.health, 1.0, 0.001)
	CrossingRig.run(crossing, 0.1)
	assert_true(rider.meters.dead)
	assert_eq(rider.meters.death_cause, &"drowning")


func test_a_crossing_bite_names_the_reef_shark() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 60.0, 60.0)
	crossing.throw_in(1)
	var rider := crossing.body_of(1)
	rider.meters.solo = true
	rider.meters.health = 25.0
	crossing.bite_swimmer(1)
	assert_true(rider.meters.dead)
	assert_eq(rider.meters.death_cause, SHARK)


func test_the_cause_is_replicated_before_the_death() -> void:
	var body := _body()
	var config := (body.get_node(^"StateSync") as MultiplayerSynchronizer).replication_config
	var paths: Array[NodePath] = config.get_properties()
	var cause_at: int = paths.find(NodePath("SurvivalMeters:death_cause"))
	var dead_at: int = paths.find(NodePath("SurvivalMeters:dead"))
	assert_gte(cause_at, 0, "the cause is replicated")
	assert_lt(cause_at, dead_at, "before dead, so a client's died already sees it")
	assert_true(config.property_get_spawn(paths[cause_at]))
	assert_eq(config.property_get_replication_mode(paths[cause_at]), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)


func test_cause_labels() -> void:
	var catalog: ContentCatalog = GameState.content
	assert_eq(DeathCause.label(&"thirst", catalog), "sed")
	assert_eq(DeathCause.label(&"drowning", catalog), "ahogamiento")
	assert_eq(DeathCause.label(&"removed", catalog), "desconexión")
	assert_eq(DeathCause.label(&"other", catalog), "causa desconocida")
	assert_eq(DeathCause.label(SHARK, catalog), "Tiburón de arrecife")
	assert_eq(DeathCause.label(CRAB, catalog), "Cangrejo")
	assert_eq(DeathCause.label(&"barracuda", catalog), "causa desconocida")


func test_a_cause_from_the_network_is_checked() -> void:
	var catalog: ContentCatalog = GameState.content
	assert_eq(DeathCause.checked(SHARK, catalog), SHARK)
	assert_eq(DeathCause.checked("thirst", catalog), &"thirst")
	assert_eq(DeathCause.checked(&"../x", catalog), &"other")
	assert_eq(DeathCause.checked(42, catalog), &"other")
	assert_eq(DeathCause.checked(&"", catalog), &"other")
	assert_eq(DeathCause.checked(&"", catalog, DeathCause.REMOVED), &"removed")


func test_of_reads_the_recorded_cause_or_other() -> void:
	var meters := _meters()
	assert_eq(DeathCause.of(meters), &"", "alive")
	meters.dead = true
	assert_eq(DeathCause.of(meters), &"other", "dead with no recorded cause")
	meters.death_cause = SHARK
	assert_eq(DeathCause.of(meters), SHARK)
