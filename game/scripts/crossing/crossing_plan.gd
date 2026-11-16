class_name CrossingPlan
extends RefCounted
## The ordered events of one crossing, rolled once on the host (crossing "Threat plan"). Clients
## receive it and never roll it. `events` is typed with the base class (a typed array of a
## class_name type that uses itself leaks at exit).
## The roll is the crossing's director (crossing "Crossing pacing", "The squall's blow in the plan";
## design.md D8): beats spread through the crossing so a rider always has something to decide, a
## squall's blow kept clear, and the reef line last.

var length_s: float = 0.0
var events: Array[RefCounted] = []


static func create(length: float, list: Array[RefCounted] = []) -> CrossingPlan:
	var plan := CrossingPlan.new()
	plan.length_s = length
	plan.events = list
	plan._sort()
	return plan


## Rolls the plan for `route` in `band` under `sky` for `riders` riders. A squall warned or running
## on entering follows the riders; otherwise a crossing long enough to hold the warning rolls its
## own. The shark pass comes by the band's chance; the other beats are paced (design.md D8).
static func roll(route: RouteData, band: DataEnums.DistanceBand, sky: WorldSky, rng: RandomNumberGenerator, tuning: CrossingTuning, riders: int = 1) -> CrossingPlan:
	var plan := CrossingPlan.new()
	plan.length_s = rng.randf_range(route.duration_s.x, route.duration_s.y)
	var weather := sky.weather
	if weather.pending != null and weather.pending.id == &"squall":
		plan._add(weather.pending_in_s, CrossingBeat.Kind.SQUALL)
	elif weather.current != null and weather.current.id == &"squall" and weather.current_left_s > 0.0:
		plan._add(tuning.running_squall_grace_s, CrossingBeat.Kind.SQUALL)
	elif weather.pending == null:
		plan._roll_own_squall(route, sky, rng, tuning)
	var shark_chance: float = tuning.shark_chance.get(band, 0.0) * route.shark_multiplier * route.threat_multiplier
	var has_shark: bool = rng.randf() < shark_chance
	plan._pace(route, band, rng, tuning, maxi(riders, 1), has_shark)
	plan._sort()
	return plan


## The time of the plan's squall hit, or −1 with none.
func squall_hit_s() -> float:
	for item: RefCounted in events:
		var event := item as CrossingBeat
		if event.kind == CrossingBeat.Kind.SQUALL:
			return event.time_s
	return -1.0


## Events with from_s < time <= to_s, in time order.
func due(from_s: float, to_s: float) -> Array[RefCounted]:
	var list: Array[RefCounted] = []
	for item: RefCounted in events:
		var event := item as CrossingBeat
		if event.time_s > from_s and event.time_s <= to_s:
			list.append(event)
	return list


## The index of `beat` in `events`, or −1: how a beat is named on the wire (taken flotsam, shooed passes).
func index_of(beat: CrossingBeat) -> int:
	return events.find(beat)


## The beat at `index`, or null.
func beat_at(index: int) -> CrossingBeat:
	return events[index] as CrossingBeat if index >= 0 and index < events.size() else null


func to_array() -> Array:
	var list: Array = []
	for item: RefCounted in events:
		list.append((item as CrossingBeat).to_array())
	return [length_s, list]


## Null for malformed data (a client never trusts what arrives). Flotsam indexes are checked
## against `pieces` (the crossing tuning's table by default).
static func from_array(data: Variant, pieces: int = -1) -> CrossingPlan:
	if not data is Array or (data as Array).size() != 2:
		return null
	var pair: Array = data
	if not (pair[0] is float or pair[0] is int) or not pair[1] is Array or not is_finite(float(pair[0])):
		return null
	if pieces < 0:
		pieces = CrossingTuning.standard().flotsam_items.size()
	var plan := CrossingPlan.new()
	plan.length_s = float(pair[0])
	for raw: Variant in pair[1]:
		var event := CrossingBeat.from_array(raw, pieces)
		if event == null:
			return null
		plan.events.append(event)
	plan._sort()
	return plan


func _add(time_s: float, kind: CrossingBeat.Kind, lane: int = 0, extra: int = 0) -> CrossingBeat:
	var beat := CrossingBeat.create(time_s, kind, lane, extra)
	events.append(beat)
	return beat


func _roll_own_squall(route: RouteData, sky: WorldSky, rng: RandomNumberGenerator, tuning: CrossingTuning) -> void:
	var squall := GameState.content.get_entry(WorldSky.WEATHER_TYPE, &"squall") as WeatherData
	if squall == null:
		return
	var latest_warn: float = length_s - squall.warning_lead_s - tuning.event_margin_s
	if latest_warn < 0.0:
		return
	var states: Array[WeatherData] = []
	for id: StringName in GameState.content.list_ids(WorldSky.WEATHER_TYPE):
		states.append(GameState.content.get_entry(WorldSky.WEATHER_TYPE, id) as WeatherData)
	var chance: float = WeatherCycle.chance_of(states, &"squall", sky.clock.phase()) * route.threat_multiplier
	if rng.randf() >= chance:
		return
	var warn_at: float = rng.randf_range(0.0, latest_warn)
	_add(warn_at, CrossingBeat.Kind.SQUALL_WARN)
	_add(warn_at + squall.warning_lead_s, CrossingBeat.Kind.SQUALL)


# The paced beats (design.md D8): times spread evenly from the first beat to the reef line with a
# little jitter, the squall's blow cleared and a hazard put before its hit, gaps repaired to the
# limits, then a kind and a lane for each.
func _pace(route: RouteData, band: DataEnums.DistanceBand, rng: RandomNumberGenerator, tuning: CrossingTuning, riders: int, has_shark: bool) -> void:
	var factor: float = pow(tuning.rider_gap_factor, riders - 1)
	var max_gap: float = tuning.max_gap_s * factor
	var target: float = tuning.target_gap_s * factor
	var jitter: float = tuning.gap_jitter_s * factor * 0.5
	var reef_at: float = length_s - tuning.reef_before_end_s
	var first: float = tuning.calm_start_s + rng.randf() * tuning.first_beat_spread_s
	var times: Array[float] = []
	if reef_at - first >= tuning.min_gap_s:
		var gaps: int = ceili((reef_at - first) / target)
		var step: float = (reef_at - first) / gaps
		for index: int in gaps:
			var shift: float = 0.0 if index == 0 else rng.randf_range(-jitter, jitter)
			times.append(first + index * step + shift)
	# A squall that hits after the crossing has ended paces nothing.
	var hit: float = squall_hit_s()
	if hit >= length_s:
		hit = -1.0
	var blow_end: float = hit + tuning.squall_blow_s if hit >= 0.0 else -1.0
	var pre_squall: float = -1.0
	if hit >= 0.0:
		var kept: Array[float] = []
		for at: float in times:
			if at <= hit - tuning.min_gap_s or at >= blow_end:
				kept.append(at)
		times = kept
		if hit >= tuning.pre_squall_min_hit_s:
			var inside: Array[float] = []
			for at: float in times:
				if at >= hit - tuning.pre_squall_window_s and at <= hit - tuning.min_gap_s:
					inside.append(at)
			if inside.is_empty():
				pre_squall = maxf(hit - rng.randf_range(tuning.pre_squall_s.x, tuning.pre_squall_s.y), tuning.calm_start_s)
				var spaced: Array[float] = []
				for at: float in times:
					if absf(at - pre_squall) >= tuning.min_gap_s:
						spaced.append(at)
				times = spaced
				times.append(pre_squall)
			else:
				pre_squall = inside[rng.randi_range(0, inside.size() - 1)]
	times = _repaired(times, tuning, max_gap, hit, blow_end, reef_at, pre_squall)
	var shark_index: int = -1
	if has_shark and not times.is_empty():
		var candidates: Array[int] = []
		for index: int in times.size():
			if times[index] != pre_squall:
				candidates.append(index)
		if not candidates.is_empty():
			shark_index = candidates[rng.randi_range(0, candidates.size() - 1)]
	for index: int in times.size():
		var at: float = times[index]
		if index == shark_index:
			_add(at, CrossingBeat.Kind.SHARK_PASS, 0, rng.randi_range(0, 1))
			continue
		var kind: CrossingBeat.Kind = _rolled_kind(route, band, rng, tuning, at == pre_squall)
		if kind == CrossingBeat.Kind.FLOTSAM:
			var sign_value: int = 1 if rng.randf() < 0.5 else -1
			_add(at, kind, sign_value * rng.randi_range(tuning.flotsam_lanes.x, tuning.flotsam_lanes.y), _rolled_piece(rng, tuning))
		else:
			_add(at, kind, rng.randi_range(-tuning.hazard_lane_max, tuning.hazard_lane_max))
	if reef_at > 0.0:
		var gap_lane: int = rng.randi_range(-tuning.reef_gap_lane_max, tuning.reef_gap_lane_max)
		_add(reef_at, CrossingBeat.Kind.ROCK, gap_lane - tuning.reef_half_gap_tiles)
		_add(reef_at, CrossingBeat.Kind.ROCK, gap_lane + tuning.reef_half_gap_tiles)


# Sorted times with every gap between neighbours at most `max_gap` (a gap is split at its middle)
# and every gap at least the minimum (a rolled time goes, never the pre-squall hazard). The squall
# hit and the reef line are fixed points that count; the gap across the blow is exempt, but the
# first time after it comes within `max_gap` of its end.
static func _repaired(times: Array[float], tuning: CrossingTuning, max_gap: float, hit: float, blow_end: float, reef_at: float, pre_squall: float) -> Array[float]:
	const EPS: float = 0.0001
	var rolled: Array[float] = times.duplicate()
	for pass_index: int in 64:
		rolled.sort()
		var marks: Array[float] = rolled.duplicate()
		if hit >= 0.0:
			marks.append(hit)
		marks.append(reef_at)
		marks.sort()
		var changed: bool = false
		for index: int in range(1, marks.size()):
			var before: float = marks[index - 1]
			var after: float = marks[index]
			if after - before < tuning.min_gap_s - EPS:
				var victim: float = -1.0
				if rolled.has(after) and after != pre_squall:
					victim = after
				elif rolled.has(before) and before != pre_squall:
					victim = before
				if victim >= 0.0:
					rolled.erase(victim)
					changed = true
					break
				continue
			if hit >= 0.0 and before >= hit - EPS and before < blow_end:
				if after > blow_end + max_gap + EPS:
					rolled.append(blow_end + max_gap * 0.5)
					changed = true
					break
				continue
			if after - before > max_gap + EPS:
				rolled.append((before + after) * 0.5)
				changed = true
				break
		if not changed:
			break
	rolled.sort()
	return rolled


static func _rolled_kind(route: RouteData, band: DataEnums.DistanceBand, rng: RandomNumberGenerator, tuning: CrossingTuning, hazard_only: bool) -> CrossingBeat.Kind:
	var rock: float = tuning.beat_weight(CrossingBeat.Kind.ROCK, band) * route.threat_multiplier
	var debris: float = tuning.beat_weight(CrossingBeat.Kind.DEBRIS, band) * route.threat_multiplier
	var flotsam: float = 0.0 if hazard_only else tuning.beat_weight(CrossingBeat.Kind.FLOTSAM, band)
	var total: float = rock + debris + flotsam
	if total <= 0.0:
		return CrossingBeat.Kind.ROCK if hazard_only else CrossingBeat.Kind.FLOTSAM
	var pick: float = rng.randf() * total
	if pick < rock:
		return CrossingBeat.Kind.ROCK
	if pick < rock + debris:
		return CrossingBeat.Kind.DEBRIS
	return CrossingBeat.Kind.FLOTSAM


static func _rolled_piece(rng: RandomNumberGenerator, tuning: CrossingTuning) -> int:
	var total: float = 0.0
	for weight: float in tuning.flotsam_weights:
		total += weight
	var pick: float = rng.randf() * total
	for index: int in tuning.flotsam_weights.size():
		pick -= tuning.flotsam_weights[index]
		if pick < 0.0:
			return index
	return maxi(tuning.flotsam_weights.size() - 1, 0)


# By time, then kind, lane and extra, so beats at the same time (the reef line's two rocks) keep
# one order on every peer and their indexes match.
func _sort() -> void:
	events.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return CrossingPlan._before(a as CrossingBeat, b as CrossingBeat))


static func _before(a: CrossingBeat, b: CrossingBeat) -> bool:
	if a.time_s != b.time_s:
		return a.time_s < b.time_s
	if a.kind != b.kind:
		return a.kind < b.kind
	if a.lane != b.lane:
		return a.lane < b.lane
	return a.extra < b.extra
