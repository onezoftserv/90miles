extends GutTest
## crossing "Crossing pacing" and "The squall's blow in the plan": the host's rolled plan never goes
## quiet for long, leaves a squall's blow clear with a hazard before the hit, and ends with the
## reef line, with exactly 1 player and with 4.

const K := CrossingBeat.Kind
## Seeds per rider count: enough to meet every branch of the director, kept small for CI's GUT step.
const SEEDS: int = 600
const EPS: float = 0.001

var tuning: CrossingTuning
var sky: WorldSky


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	sky = WeatherManager.sky
	tuning = CrossingTuning.standard()


func after_each() -> void:
	WeatherManager.stop()


func _raft() -> RouteData:
	return (GameState.content.get_entry(&"routes", &"raft") as RouteData).duplicate() as RouteData


func _roll(route: RouteData, seed_value: int, riders: int) -> CrossingPlan:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CrossingPlan.roll(route, DataEnums.DistanceBand.COAST, sky, rng, tuning, riders)


# Distinct beat times in order, the squall's warning left out (it is not a decision).
func _times(plan: CrossingPlan) -> Array[float]:
	var found: Array[float] = []
	for item: RefCounted in plan.events:
		var beat := item as CrossingBeat
		if beat.kind == K.SQUALL_WARN:
			continue
		if found.is_empty() or absf(found[-1] - beat.time_s) > EPS:
			found.append(beat.time_s)
	return found


func _rolled_times(plan: CrossingPlan) -> Array[float]:
	var found: Array[float] = []
	var reef: float = plan.length_s - tuning.reef_before_end_s
	for item: RefCounted in plan.events:
		var beat := item as CrossingBeat
		if beat.kind == K.SQUALL_WARN or beat.kind == K.SQUALL or absf(beat.time_s - reef) < EPS:
			continue
		found.append(beat.time_s)
	return found


# Checks the spacing rules on `plan` rolled for `riders`; returns the first problem or "".
func _problem(plan: CrossingPlan, riders: int) -> String:
	var max_gap: float = tuning.max_gap_s * pow(tuning.rider_gap_factor, riders - 1)
	var hit: float = plan.squall_hit_s()
	if hit >= plan.length_s:
		hit = -1.0
	var blow_end: float = hit + tuning.squall_blow_s
	var reef: float = plan.length_s - tuning.reef_before_end_s
	var rolled := _rolled_times(plan)
	for at: float in rolled:
		if at < tuning.calm_start_s - EPS:
			return "a rolled beat at %.2f s, inside the calm start" % at
		if hit >= 0.0 and at > hit + EPS and at < blow_end - EPS:
			return "a rolled beat at %.2f s, inside the blow from %.2f s" % [at, hit]
	if not rolled.is_empty():
		var first_covered: bool = hit >= 0.0 and hit < tuning.calm_start_s + tuning.first_beat_spread_s + tuning.min_gap_s
		if not first_covered and (rolled[0] < tuning.calm_start_s - EPS or rolled[0] > tuning.calm_start_s + tuning.first_beat_spread_s + EPS):
			return "the first rolled beat at %.2f s" % rolled[0]
	var reef_rocks: int = 0
	for item: RefCounted in plan.events:
		var beat := item as CrossingBeat
		if beat.kind == K.ROCK and absf(beat.time_s - reef) < EPS:
			reef_rocks += 1
	if reef_rocks != 2:
		return "%d reef rocks" % reef_rocks
	var times := _times(plan)
	if absf(times[-1] - reef) > EPS:
		return "the last beat at %.2f s, not the reef line at %.2f s" % [times[-1], reef]
	for index: int in range(1, times.size()):
		var before: float = times[index - 1]
		var after: float = times[index]
		if after - before < tuning.min_gap_s - EPS:
			var fixed_pair: bool = (absf(before - hit) < EPS or absf(before - reef) < EPS) and (absf(after - hit) < EPS or absf(after - reef) < EPS)
			if not fixed_pair:
				return "%.2f and %.2f are less than 3 s apart" % [before, after]
		var across_blow: bool = hit >= 0.0 and before >= hit - EPS and before < blow_end
		if across_blow:
			if after > blow_end + max_gap + EPS and absf(after - reef) > EPS:
				return "%.2f comes more than the max gap after the blow ends at %.2f" % [after, blow_end]
			continue
		if after - before > max_gap + EPS:
			return "%.2f and %.2f are more than %.2f s apart" % [before, after, max_gap]
	if hit >= tuning.pre_squall_min_hit_s:
		var hazard_before: bool = false
		for item: RefCounted in plan.events:
			var beat := item as CrossingBeat
			if (beat.kind == K.ROCK or beat.kind == K.DEBRIS) and beat.time_s >= hit - tuning.pre_squall_window_s - EPS and beat.time_s < hit:
				hazard_before = true
		if not hazard_before:
			return "no rock or debris in the 10 s before the hit at %.2f" % hit
	return ""


func test_a_solo_plan_never_goes_quiet() -> void:
	var route := _raft()
	var failures: int = 0
	for seed_value: int in SEEDS:
		var problem := _problem(_roll(route, seed_value, 1), 1)
		if problem != "":
			failures += 1
			if failures <= 5:
				fail_test("seed %d: %s" % [seed_value, problem])
	assert_eq(failures, 0, "every solo plan keeps the pacing rules")


func test_four_riders_get_a_denser_plan() -> void:
	var route := _raft()
	var failures: int = 0
	var solo_beats: int = 0
	var crew_beats: int = 0
	for seed_value: int in SEEDS:
		var plan := _roll(route, seed_value, 4)
		crew_beats += _rolled_times(plan).size()
		solo_beats += _rolled_times(_roll(route, seed_value, 1)).size()
		var problem := _problem(plan, 4)
		if problem != "":
			failures += 1
			if failures <= 5:
				fail_test("seed %d: %s" % [seed_value, problem])
	assert_eq(failures, 0, "every 4-rider plan keeps the denser rules")
	assert_gt(crew_beats, solo_beats, "four riders get more beats than one")


func test_a_squall_warned_on_the_island_keeps_its_blow_clear() -> void:
	var route := _raft()
	for seed_value: int in 300:
		sky.weather.apply(&"calm", 100.0, &"squall", 50.0)
		var plan := _roll(route, seed_value, 1)
		assert_eq(plan.squall_hit_s(), 50.0)
		var problem := _problem(plan, 1)
		assert_eq(problem, "", "seed %d" % seed_value)
		for at: float in _rolled_times(plan):
			assert_false(at > 50.0 and at < 65.0, "no rolled beat in the blow (seed %d at %.2f)" % [seed_value, at])


func test_a_squall_carried_from_the_island_hits_early() -> void:
	var route := _raft()
	for seed_value: int in 300:
		sky.weather.apply(&"calm", 100.0, &"squall", 4.0)
		var plan := _roll(route, seed_value, 1)
		var rolled := _rolled_times(plan)
		assert_eq(plan.squall_hit_s(), 4.0)
		assert_gt(rolled[0], 19.0 - EPS, "nothing rolled before the blow ends (seed %d)" % seed_value)
		assert_lt(rolled[0], 28.0 + EPS, "and the first beat comes within 9 s of it (seed %d)" % seed_value)


func test_the_reef_line_stays_inside_a_blow() -> void:
	var route := _raft()
	route.duration_s = Vector2(75, 75)
	sky.weather.apply(&"calm", 100.0, &"squall", 62.0)
	var plan := _roll(route, 9, 1)
	var reef_rocks: Array[int] = []
	for item: RefCounted in plan.events:
		var beat := item as CrossingBeat
		if beat.kind == K.ROCK and absf(beat.time_s - 71.0) < EPS:
			reef_rocks.append(beat.lane)
	assert_eq(reef_rocks.size(), 2, "the reef line is at 71 s inside the blow from 62 s")
	assert_eq(reef_rocks[1] - reef_rocks[0], 10, "two rocks 10 tiles apart")
	assert_between((reef_rocks[0] + reef_rocks[1]) / 2, -3, 3, "the gap within 3 tiles of the line")


func test_same_seed_same_plan_with_lanes_and_sides() -> void:
	var route := _raft()
	for seed_value: int in 50:
		for riders: int in [1, 2, 4]:
			assert_eq(_roll(route, seed_value, riders).to_array(), _roll(route, seed_value, riders).to_array())


func test_a_solo_plan_is_rolled_for_one_rider() -> void:
	var route := _raft()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var default_plan := CrossingPlan.roll(route, DataEnums.DistanceBand.COAST, sky, rng, tuning)
	assert_eq(default_plan.to_array(), _roll(route, 77, 1).to_array(), "no rider count means one rider")


func test_rolled_lanes_and_pieces_are_in_range() -> void:
	var route := _raft()
	for seed_value: int in 500:
		var plan := _roll(route, seed_value, 1)
		var reef: float = plan.length_s - tuning.reef_before_end_s
		for item: RefCounted in plan.events:
			var beat := item as CrossingBeat
			match beat.kind:
				K.ROCK, K.DEBRIS:
					if absf(beat.time_s - reef) > EPS:
						assert_between(beat.lane, -tuning.hazard_lane_max, tuning.hazard_lane_max)
				K.FLOTSAM:
					assert_between(absi(beat.lane), tuning.flotsam_lanes.x, tuning.flotsam_lanes.y)
					assert_between(beat.extra, 0, tuning.flotsam_items.size() - 1)
				K.SHARK_PASS:
					assert_between(beat.extra, 0, 1)
		assert_eq(CrossingPlan.from_array(plan.to_array()).to_array(), plan.to_array(), "it survives the wire")


func test_the_swimmers_route_is_paced_too() -> void:
	var route := (GameState.content.get_entry(&"routes", &"binoculars_swim") as RouteData).duplicate() as RouteData
	for seed_value: int in 200:
		assert_eq(_problem(_roll(route, seed_value, 1), 1), "", "seed %d" % seed_value)
