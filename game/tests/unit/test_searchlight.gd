extends GutTest
## guardacostas-stealth, group 3 (design.md decision 4): the beam's centre aims at the island's
## centroid and swings +/- 60 degrees as a triangle wave at 30 degrees per second, so a full
## back-and-forth takes 8 s; a point is lit within the range and within half the cone of the beam.
## Pure: no scene, no physics. Angles are degrees, in screen space (y down), like Vector2.angle().

const FIXTURES: String = "res://tests/fixtures/content"
const TOLERANCE: float = 0.000001
const NIGHT := DataEnums.DayPhase.NIGHT

var light: Searchlight
var boat: Vector2 = Vector2(10.0, 10.0)
var centroid: Vector2 = Vector2(30.0, 10.0)


func before_each() -> void:
	light = Searchlight.from_patrol(_patrol())


func _patrol() -> PatrolData:
	return (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol


# A point `tiles` from the boat at `degrees` from the +x axis.
func _at(degrees: float, tiles: float) -> Vector2:
	return boat + Vector2.from_angle(deg_to_rad(degrees)) * tiles


func test_it_reads_the_patrol_data() -> void:
	assert_almost_eq(light.cone_deg, 60.0, TOLERANCE)
	assert_almost_eq(light.range_tiles, 10.0, TOLERANCE)
	assert_almost_eq(light.sweep_deg_s, 30.0, TOLERANCE)
	assert_almost_eq(light.arc_deg, 120.0, TOLERANCE)
	assert_eq(light.phases, [NIGHT])


# --- the sweep ---------------------------------------------------------------------------------

func test_the_offset_is_a_triangle_wave_of_8_s_and_plus_minus_60_degrees() -> void:
	assert_almost_eq(light.period_s(), 8.0, TOLERANCE)
	var expected: Dictionary[float, float] = {
		0.0: 0.0, 1.0: 30.0, 2.0: 60.0, 3.0: 30.0, 4.0: 0.0, 5.0: -30.0, 6.0: -60.0, 7.0: -30.0, 8.0: 0.0, 10.0: 60.0,
	}
	for t: float in expected:
		assert_almost_eq(light.offset_deg(t), expected[t], 0.0001, "at %s s" % t)


func test_the_beam_stays_within_60_degrees_of_the_island_line_and_is_back_after_8_s() -> void:
	var line: float = rad_to_deg((centroid - boat).angle())
	var highest: float = -INF
	var lowest: float = INF
	for tick: int in 480:
		var t: float = tick / 60.0
		var away: float = light.beam_deg(boat, centroid, t) - line
		highest = maxf(highest, away)
		lowest = minf(lowest, away)
	assert_almost_eq(highest, 60.0, 0.01)
	assert_almost_eq(lowest, -60.0, 0.01)
	assert_almost_eq(light.beam_deg(boat, centroid, 8.0), light.beam_deg(boat, centroid, 0.0), 0.0001)
	assert_almost_eq(light.beam_deg(boat, centroid, 0.0), line, 0.0001, "time in sight 0 is the island line")


func test_the_beam_reverses_at_each_end() -> void:
	assert_gt(light.offset_deg(1.9), light.offset_deg(1.0), "rising")
	assert_gt(light.offset_deg(2.0), light.offset_deg(2.1), "turns at +60")
	assert_gt(light.offset_deg(5.9), light.offset_deg(6.0), "falling")
	assert_gt(light.offset_deg(6.1), light.offset_deg(6.0), "turns at -60")


func test_no_sweep_when_the_data_gives_no_speed_or_arc() -> void:
	light.sweep_deg_s = 0.0
	assert_eq(light.offset_deg(3.0), 0.0)
	light.sweep_deg_s = 30.0
	light.arc_deg = 0.0
	assert_eq(light.offset_deg(3.0), 0.0)


# --- the cone ----------------------------------------------------------------------------------

func test_the_range_is_10_tiles() -> void:
	assert_true(light.is_lit(_at(0.0, 9.9), boat, 0.0))
	assert_false(light.is_lit(_at(0.0, 10.1), boat, 0.0))
	assert_true(light.is_lit(_at(0.0, 10.0), boat, 0.0), "the edge counts")


func test_the_cone_is_60_degrees_wide() -> void:
	assert_true(light.is_lit(_at(29.0, 5.0), boat, 0.0))
	assert_false(light.is_lit(_at(31.0, 5.0), boat, 0.0))
	assert_true(light.is_lit(_at(-29.0, 5.0), boat, 0.0))
	assert_false(light.is_lit(_at(-31.0, 5.0), boat, 0.0))
	assert_true(light.is_lit(_at(30.0, 5.0), boat, 0.0), "the edge counts")


func test_the_cone_wraps_across_180_degrees() -> void:
	assert_true(light.is_lit(_at(-179.0, 5.0), boat, 179.0), "2 degrees apart across the seam")
	assert_true(light.is_lit(_at(171.0, 5.0), boat, -179.0), "10 degrees apart the other way")
	assert_false(light.is_lit(_at(-150.0, 5.0), boat, 179.0), "31 degrees apart across the seam")
	assert_true(light.is_lit(_at(-170.0, 5.0), boat, 190.0), "a beam outside -180..180 compares by the short way")
	assert_false(light.is_lit(_at(-170.0, 5.0), boat, 230.0), "40 degrees apart the short way")


func test_the_beam_follows_the_beam_angle_not_the_island_line() -> void:
	# Time 2 s: the beam is 60 degrees round from the island line, so the island line is dark.
	var beam: float = light.beam_deg(boat, centroid, 2.0)
	assert_false(light.is_lit(_at(0.0, 5.0), boat, beam), "the island line at 5 tiles is 60 degrees off the beam")
	assert_true(light.is_lit(_at(60.0, 5.0), boat, beam))


func test_a_point_on_the_boat_is_lit() -> void:
	assert_true(light.is_lit(boat, boat, 0.0))


func test_lights_combines_the_sweep_and_the_cone() -> void:
	# At 0 s the beam is on the island line (east): a point 5 tiles east is lit, 5 tiles north is not.
	assert_true(light.lights(boat + Vector2(5.0, 0.0), boat, centroid, 0.0))
	assert_false(light.lights(boat + Vector2(0.0, -5.0), boat, centroid, 0.0))
	# At 4 s it is back on the line; at 2 s it has swung 60 degrees, to the south on screen.
	assert_true(light.lights(boat + Vector2(5.0, 0.0), boat, centroid, 4.0))
	assert_false(light.lights(boat + Vector2(5.0, 0.0), boat, centroid, 2.0))


# --- on and off --------------------------------------------------------------------------------

func test_the_light_is_on_only_at_night() -> void:
	assert_true(light.is_on(NIGHT, []))
	for phase: DataEnums.DayPhase in [DataEnums.DayPhase.DAWN, DataEnums.DayPhase.DAY, DataEnums.DayPhase.DUSK]:
		assert_false(light.is_on(phase, []), str(phase))


func test_the_light_is_off_when_the_weather_disables_sight() -> void:
	var fog := ContentCatalog.new(FIXTURES).get_entry(&"weather", &"fog_test") as WeatherData
	assert_false(light.is_on(NIGHT, fog.disabled_senses))
	var no_senses: Array[DataEnums.Sense] = []
	assert_true(light.is_on(NIGHT, no_senses))
	assert_true(light.is_on(NIGHT, [DataEnums.Sense.HEARING] as Array[DataEnums.Sense]), "other senses do not matter")


func test_a_45_degree_copy_sweeps_a_45_degree_cone() -> void:
	var copy := (ContentCatalog.new(FIXTURES).get_entry(&"creatures", &"patrol_test") as CreatureData).patrol
	var narrow := Searchlight.from_patrol(copy)
	assert_almost_eq(narrow.cone_deg, 45.0, TOLERANCE)
	assert_true(narrow.is_lit(_at(22.0, 5.0), boat, 0.0))
	assert_false(narrow.is_lit(_at(23.0, 5.0), boat, 0.0))
	assert_true(light.is_lit(_at(23.0, 5.0), boat, 0.0), "the shipped 60 degree cone still lights it")
