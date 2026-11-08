extends GutTest
## status-sync, offline with 1 player: a player's statuses are bit flags in SurvivalMeters, one per
## DataEnums.Status, with statuses_changed on each change, whether set_status or the sync brought
## it. A solo shark bite still bleeds.

const BLEEDING := DataEnums.Status.BLEEDING
const POISON := DataEnums.Status.POISON
const SHARK := CrossingBeat.Kind.SHARK_PASS


func after_each() -> void:
	NetManager.leave()


func _meters() -> SurvivalMeters:
	var meters := SurvivalMeters.new()
	autofree(meters)
	return meters


func test_a_status_sets_and_clears_its_own_bit() -> void:
	var meters := _meters()
	meters.set_status(BLEEDING, true)
	assert_eq(meters.status_flags, 1 << BLEEDING)
	assert_true(meters.has_status(BLEEDING))
	assert_false(meters.has_status(DataEnums.Status.BURNING))
	meters.set_status(POISON, true)
	assert_eq(meters.status_flags, (1 << BLEEDING) | (1 << POISON))
	meters.set_status(BLEEDING, false)
	assert_eq(meters.status_flags, 1 << POISON)
	assert_false(meters.has_status(BLEEDING))


func test_statuses_changed_once_per_change() -> void:
	var meters := _meters()
	watch_signals(meters)
	meters.set_status(BLEEDING, true)
	meters.set_status(BLEEDING, true)
	assert_signal_emit_count(meters, "statuses_changed", 1, "a repeat changes nothing")
	assert_signal_emitted_with_parameters(meters, "statuses_changed", [1 << BLEEDING])
	meters.set_status(BLEEDING, false)
	assert_signal_emit_count(meters, "statuses_changed", 2)


func test_none_and_unknown_statuses_change_nothing() -> void:
	var meters := _meters()
	meters.set_status(DataEnums.Status.NONE, true)
	meters.set_status(99 as DataEnums.Status, true)
	meters.set_status(-1 as DataEnums.Status, true)
	assert_eq(meters.status_flags, 0)
	assert_false(meters.has_status(99 as DataEnums.Status))


func test_flags_set_from_outside_signal_too() -> void:
	# What the player's synchronizer does on a client.
	var meters := _meters()
	watch_signals(meters)
	meters.status_flags = 1 << BLEEDING
	assert_true(meters.has_status(BLEEDING))
	assert_signal_emitted_with_parameters(meters, "statuses_changed", [1 << BLEEDING])


func test_the_player_sync_carries_the_statuses() -> void:
	var body := CoopSession.PLAYER_SCENE.instantiate() as PlayerBody
	autofree(body)
	var synced: bool = false
	for sync: Node in body.find_children("*", "MultiplayerSynchronizer", true, false):
		var config := (sync as MultiplayerSynchronizer).replication_config
		if config != null and config.has_property(NodePath("SurvivalMeters:status_flags")):
			synced = config.property_get_spawn(NodePath("SurvivalMeters:status_flags"))
	assert_true(synced, "sent with the spawn and after it, like the meters")


func test_solo_shark_bite_still_bleeds() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(1.0, SHARK)])
	var body := crossing.body_of(1)
	crossing.throw_in(1)
	body.meters.energy = 15.0
	CrossingRig.run(crossing, 1.1)
	assert_true(body.meters.has_status(BLEEDING))
	assert_eq(body.meters.status_flags, 1 << BLEEDING)
