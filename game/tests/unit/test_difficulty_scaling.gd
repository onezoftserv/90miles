extends GutTest
## coop-networking "Difficulty scaling" (approved 2026-11-05): counted from the living,
## connected players when each island is set up. Resources ×0.8 per such player beyond the
## first, patrols +1 per 2 such players (rounded down). One player gets the base numbers.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")


func _session_with(extra_peers: Array[int]) -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	for peer_id: int in extra_peers:
		session._add_player(peer_id)
	return session


func _dead_in(dead_peers: Array[int]) -> Callable:
	return func(body: PlayerBody) -> bool: return not dead_peers.has(int(String(body.name)))


func test_one_player_gets_the_base_numbers() -> void:
	var scaling := DifficultyScaling.for_players(1)
	assert_eq(scaling.resource_multiplier, 1.0)
	assert_eq(scaling.extra_patrols, 0)


func test_two_three_and_four_players() -> void:
	assert_almost_eq(DifficultyScaling.for_players(2).resource_multiplier, 0.8, 0.000001)
	assert_eq(DifficultyScaling.for_players(2).extra_patrols, 1)
	assert_almost_eq(DifficultyScaling.for_players(3).resource_multiplier, 0.64, 0.000001)
	assert_eq(DifficultyScaling.for_players(3).extra_patrols, 1)
	assert_almost_eq(DifficultyScaling.for_players(4).resource_multiplier, 0.512, 0.000001)
	assert_eq(DifficultyScaling.for_players(4).extra_patrols, 2)


func test_no_players_counts_as_one() -> void:
	assert_eq(DifficultyScaling.for_players(0).players, 1)
	assert_eq(DifficultyScaling.for_players(-3).resource_multiplier, 1.0)


func test_solo_island() -> void:
	var scaling := _session_with([] as Array[int]).island_difficulty()
	assert_eq(scaling.players, 1)
	assert_eq(scaling.resource_multiplier, 1.0)
	assert_eq(scaling.extra_patrols, 0)


func test_three_players() -> void:
	var scaling := _session_with([7, 8] as Array[int]).island_difficulty()
	assert_eq(scaling.players, 3)
	assert_almost_eq(scaling.resource_multiplier, 0.64, 0.000001)
	assert_eq(scaling.extra_patrols, 1)


func test_a_four_player_run_with_three_dead() -> void:
	var session := _session_with([7, 8, 9] as Array[int])
	var scaling := session.island_difficulty(_dead_in([7, 8, 9] as Array[int]))
	assert_eq(scaling.players, 1, "the last survivor plays the base numbers")
	assert_eq(scaling.resource_multiplier, 1.0)
	assert_eq(scaling.extra_patrols, 0)


func test_dropped_players_do_not_count() -> void:
	var session := _session_with([7, 8, 9] as Array[int])
	session._dropped[9] = CoopSession.DISCONNECT_DOWNED_S
	assert_eq(session.island_difficulty().players, 3)


func test_every_player_counts_as_alive_until_meters_say_otherwise() -> void:
	var session := _session_with([7] as Array[int])
	assert_true(CoopSession.is_alive(session.body(7)))
	assert_eq(session.island_difficulty().players, 2)
