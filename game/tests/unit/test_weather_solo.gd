extends GutTest
## weather-daynight with exactly 1 player, offline: a whole day with a squall runs on the host's
## clock alone, the player's meters read the same clock, and nothing is sent.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")


func before_each() -> void:
	NetManager.start_solo()


func test_one_offline_player_lives_through_a_day_with_a_squall() -> void:
	var sky := WorldSky.from_catalog(GameState.content)
	sky.start_at(0.0)
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.sky = sky
	session.climate = sky.climate
	add_child_autofree(session)
	session.start()
	var body: PlayerBody = session.body(session.multiplayer.get_unique_id())
	assert_not_null(body)
	assert_true(body.climate == sky.climate, "the body reads the sky's climate")
	var phases: Array[DataEnums.DayPhase] = []
	var squall_started_at: float = -1.0
	var squall_ended_at: float = -1.0
	var elapsed: float = 0.0
	sky.weather.warn_weather(&"squall")
	var warned_at: float = elapsed
	while elapsed < DayClock.DAY_S:
		sky.advance(0.5)
		elapsed += 0.5
		if phases.is_empty() or phases[phases.size() - 1] != body.climate.phase:
			phases.append(body.climate.phase)
		var squall: bool = sky.weather.current.id == &"squall"
		if squall and squall_started_at < 0.0:
			squall_started_at = elapsed
		if not squall and squall_started_at >= 0.0 and squall_ended_at < 0.0:
			squall_ended_at = elapsed
	assert_eq(phases, [DataEnums.DayPhase.DAWN, DataEnums.DayPhase.DAY, DataEnums.DayPhase.DUSK, DataEnums.DayPhase.NIGHT, DataEnums.DayPhase.DAWN])
	assert_almost_eq(squall_started_at - warned_at, 60.0, 1.0)
	assert_almost_eq(squall_ended_at - squall_started_at, 120.0, 1.0)
	assert_true(session.multiplayer.get_peers().is_empty(), "no second peer")
