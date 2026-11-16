extends GutTest
## crossing-gameplay design.md "Expected loss" and Q8 (owner, 2026-11-15: idle about 30 left,
## attentive 70 or more): an idle solo rider and a scripted attentive one, each over 500 plans rolled
## for a 75 s coast raft crossing at dawn in calm weather. The attentive rider acts through the
## crossing's own host calls with human delays: it paddles out of each rock and debris lane it sees
## coming (and to the reef line's gap), plugs a leak 2.5 s after it opens, shoos a fin 2.5 s after it
## shows, and ties down for a squall 2 s before the hit and unties 1 s after. Input is tested
## elsewhere; this checks the balance of the numbers in crossing_tuning.tres.

const RUNS: int = 500
const STEP_S: float = 0.1
const LENGTH_S: float = 75.0
## How far ahead the attentive rider looks, and how long it takes to answer a leak or a fin.
const LOOK_AHEAD_S: float = 4.0
const ANSWER_S: float = 2.5
const TIE_BEFORE_S: float = 2.0
const UNTIE_AFTER_S: float = 1.0
## Margin the attentive rider keeps from a hazard's reach, in tiles.
const SAFE_TILES: float = 0.3

var session: CoopSession
var route: RouteData
var tuning: CrossingTuning


func before_all() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	route = (GameState.content.get_entry(&"routes", &"raft") as RouteData).duplicate() as RouteData
	route.duration_s = Vector2(LENGTH_S, LENGTH_S)
	tuning = CrossingTuning.standard()


func after_all() -> void:
	WeatherManager.stop()


func before_each() -> void:
	session = CrossingRig.make_session(self, 1)


func test_idle_and_attentive_solo_riders_meet_the_targets() -> void:
	var idle: Array[float] = []
	var attentive: Array[float] = []
	for seed_value: int in RUNS:
		idle.append(_ride(seed_value, false))
		attentive.append(_ride(seed_value, true))
	var idle_mean: float = _mean(idle)
	var attentive_mean: float = _mean(attentive)
	var idle_broken: float = 100.0 * idle.count(0.0) / RUNS
	var attentive_broken: float = 100.0 * attentive.count(0.0) / RUNS
	gut.p("balance over %d solo 75 s coast raft plans: idle %.1f left (%.1f %% broken), attentive %.1f left (%.1f %% broken)" % [RUNS, idle_mean, idle_broken, attentive_mean, attentive_broken])
	assert_between(idle_mean, 20.0, 40.0, "an idle rider ends with 20-40 on average")
	assert_gte(attentive_mean, 70.0, "an attentive rider ends with 70 or more on average")


# One crossing of the rolled plan for `seed_value`; returns the integrity left (0 when broken).
func _ride(seed_value: int, attentive: bool) -> float:
	# A fired squall warning leaves a pending squall on the shared sky: start each roll calm.
	WeatherManager.sky.start_at(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var plan := CrossingPlan.roll(route, DataEnums.DistanceBand.COAST, WeatherManager.sky, rng, tuning, 1)
	var crossing := Crossing.SCENE.instantiate() as Crossing
	session.add_child(crossing)
	crossing.setup(session, route, [1] as Array[int], 100.0, plan, 0)
	var body := session.body(1)
	body.meters.energy = 100.0
	body.meters.health = 100.0
	var leak_seen: Dictionary[int, float] = {}
	var tied_for: float = -1.0
	var hit: float = plan.squall_hit_s()
	while not crossing.finished:
		if attentive:
			tied_for = _act(crossing, leak_seen, hit, tied_for)
		crossing.advance(STEP_S)
	var left: float = 0.0 if crossing.integrity.broken else crossing.integrity.value
	session.remove_child(crossing)
	crossing.free()
	for child: Node in session.entities.get_children():
		child.free()
	return left


# The attentive rider's choices for this step; returns the squall hit it is tied for, or -1.
func _act(crossing: Crossing, leak_seen: Dictionary[int, float], hit: float, tied_for: float) -> float:
	var now: float = crossing.elapsed_s
	var state: Crossing.Rider = crossing.rider_state(1)
	if state == Crossing.Rider.IN_WATER or state == Crossing.Rider.DEAD:
		crossing.stop_paddling(1)
		return tied_for
	# The squall: tie down just before the hit, untie once it has passed.
	if hit >= 0.0 and tied_for < 0.0 and now >= hit - TIE_BEFORE_S and now < hit:
		crossing.stop_paddling(1)
		crossing.tie(1)
		return hit
	if tied_for >= 0.0:
		if now >= tied_for + UNTIE_AFTER_S:
			crossing.untie(1)
			return -1.0
		return tied_for
	# Leaks: plugged a moment after they open.
	for leak: Dictionary in crossing.leaks.list.duplicate():
		var id: int = leak["id"]
		if not leak_seen.has(id):
			leak_seen[id] = now
		elif now - leak_seen[id] >= ANSWER_S:
			crossing.leaks.plug(id)
	# A fin: shooed a moment after it shows.
	for index: int in crossing.fins:
		var beat := crossing.plan.beat_at(index)
		if not crossing.shooed.has(index) and now >= beat.time_s - tuning.shark_lead_s + ANSWER_S:
			crossing.shoo_shark(index)
	# Hazards in sight: paddle to the nearest clear position, or let the current take the raft back.
	var target: float = _clear_position(crossing, now)
	var position: float = crossing.steer.position
	if absf(target - position) < 0.2:
		crossing.stop_paddling(1)
	else:
		crossing.steer.start(1, CrossingSteer.EAST if target > position else CrossingSteer.WEST)
	return -1.0


# The position nearest the raft's that every rock and debris due within LOOK_AHEAD_S misses; the
# line when nothing is coming.
func _clear_position(crossing: Crossing, now: float) -> float:
	var coming: Array[CrossingBeat] = []
	for item: RefCounted in crossing.plan.events:
		var beat := item as CrossingBeat
		if (beat.kind == CrossingBeat.Kind.ROCK or beat.kind == CrossingBeat.Kind.DEBRIS) and beat.time_s > now and beat.time_s - now <= LOOK_AHEAD_S:
			coming.append(beat)
	var position: float = crossing.steer.position
	if coming.is_empty():
		return 0.0
	var best: float = position
	var best_gap: float = INF
	var candidate: float = -tuning.max_offset_tiles
	while candidate <= tuning.max_offset_tiles + 0.001:
		var clear: bool = true
		for beat: CrossingBeat in coming:
			var reach: float = tuning.vessel_width_tiles * 0.5 + crossing.beat_width_tiles(beat) * 0.5 + SAFE_TILES
			if absf(beat.lane - candidate) < reach:
				clear = false
				break
		if clear and absf(candidate - position) < best_gap:
			best = candidate
			best_gap = absf(candidate - position)
		candidate += 0.25
	return best


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / maxf(values.size(), 1.0)
