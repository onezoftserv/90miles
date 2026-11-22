extends GutTest
## guardacostas-capture, group 8 (design.md §2, specs "Whole-party capture", "Taken captives", "Capture
## outcome"): the capture rules as pure tests over member snapshots. Who is free (a downed player, one
## in a last stand and a dropped one are not; a rider waiting on the next shore or in a crossing is),
## when a capture is the whole party's, the last free player dying, who is taken when the squad leaves,
## and the router: an island or a non-final crossing plays the scene, the final crossing skips both
## the scene and the check.


func _member(flags: Dictionary = {}) -> CaptureRules.Member:
	var member := CaptureRules.Member.new()
	member.dead = flags.get("dead", false)
	member.dropped = flags.get("dropped", false)
	member.downed = flags.get("downed", false)
	member.last_stand = flags.get("last_stand", false)
	member.captive = flags.get("captive", false)
	member.taken = flags.get("taken", false)
	return member


func _members(list: Array) -> Array[CaptureRules.Member]:
	var members: Array[CaptureRules.Member] = []
	for flags: Dictionary in list:
		members.append(_member(flags))
	return members


# --- who is free -----------------------------------------------------------------------------------

func test_a_standing_connected_player_is_free_wherever_they_are() -> void:
	# A rider waiting on the next shore or riding a crossing has no capture flag: free.
	assert_true(CaptureRules.is_free(_member()))


func test_downed_last_stand_dropped_dead_captive_and_taken_players_are_not_free() -> void:
	for flag: String in ["downed", "last_stand", "dropped", "dead", "captive", "taken"]:
		assert_false(CaptureRules.is_free(_member({flag: true})), flag)


# --- the whole party -------------------------------------------------------------------------------

func test_a_lone_captive_is_a_whole_party_capture() -> void:
	assert_true(CaptureRules.is_whole_party(_members([{"captive": true}])), "solo: the first capture is the whole party's")


func test_a_free_teammate_means_it_is_not() -> void:
	assert_false(CaptureRules.is_whole_party(_members([{"captive": true}, {}])))


func test_a_rider_waiting_on_the_next_shore_counts_as_free() -> void:
	# Spec "A rider waits on the next shore": not a whole-party capture.
	assert_false(CaptureRules.is_whole_party(_members([{}, {"captive": true}])))


func test_a_downed_or_dropped_teammate_goes_along() -> void:
	assert_true(CaptureRules.is_whole_party(_members([{"captive": true}, {"downed": true}])))
	assert_true(CaptureRules.is_whole_party(_members([{"captive": true}, {"dropped": true}])))
	assert_true(CaptureRules.is_whole_party(_members([{"captive": true}, {"last_stand": true}])))


func test_nobody_caught_is_no_capture() -> void:
	assert_false(CaptureRules.is_whole_party(_members([{"downed": true}])), "a downed player alone is not captured")
	assert_false(CaptureRules.is_whole_party(_members([{"dead": true}])), "a dead party is the run's end, not a capture")
	assert_false(CaptureRules.is_whole_party(_members([])))


func test_the_last_free_player_dying_makes_it_a_whole_party_capture() -> void:
	# Spec "The last free player dies": one captive in the dinghy, the only free player dies.
	var members := _members([{"captive": true}, {}])
	assert_false(CaptureRules.is_whole_party(members))
	members[1].dead = true
	assert_true(CaptureRules.is_whole_party(members))
	# "The last free player dies after the squad has left": the captive was taken.
	assert_true(CaptureRules.is_whole_party(_members([{"taken": true}, {"dead": true}])))


# --- the taken rule --------------------------------------------------------------------------------

func test_captives_are_taken_when_the_squad_leaves_while_someone_is_free() -> void:
	assert_eq(CaptureRules.taken_on_leaving(1, _members([{"captive": true}, {}])), 1)
	assert_eq(CaptureRules.taken_on_leaving(2, _members([{"captive": true}, {"captive": true}, {}])), 2)


func test_no_captive_is_taken_when_nobody_is_free() -> void:
	assert_eq(CaptureRules.taken_on_leaving(1, _members([{"captive": true}])), 0, "a whole-party capture instead")
	assert_eq(CaptureRules.taken_on_leaving(1, _members([{"captive": true}, {"downed": true}])), 0)


# --- the router ------------------------------------------------------------------------------------

func test_an_island_or_a_non_final_crossing_plays_the_scene() -> void:
	assert_eq(CaptureOutcome.resolve(false), CaptureOutcome.Route.SCENE)
	assert_true(CaptureOutcome.checks_persuasion(CaptureOutcome.Route.SCENE))


# Main spec "A final-crossing capture skips the scene".
func test_a_final_crossing_capture_skips_the_scene_and_the_check() -> void:
	var route := CaptureOutcome.resolve(true)
	assert_eq(route, CaptureOutcome.Route.DEVUELTO)
	assert_false(CaptureOutcome.checks_persuasion(route), "no persuasion check is rolled")
