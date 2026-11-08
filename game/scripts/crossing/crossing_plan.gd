class_name CrossingPlan
extends RefCounted
## The ordered events of one crossing, rolled once on the host (crossing "Threat plan"). Clients
## receive it and never roll it. `events` is typed with the base class (a typed array of a
## class_name type that uses itself leaks at exit).

var length_s: float = 0.0
var events: Array[RefCounted] = []


static func create(length: float, list: Array[RefCounted] = []) -> CrossingPlan:
	var plan := CrossingPlan.new()
	plan.length_s = length
	plan.events = list
	plan._sort()
	return plan


## Rolls the plan for `route` in `band` under `sky`. A squall warned or running on entering
## follows the riders; otherwise a crossing long enough to hold the warning rolls its own.
static func roll(route: RouteData, band: DataEnums.DistanceBand, sky: WorldSky, rng: RandomNumberGenerator, tuning: CrossingTuning) -> CrossingPlan:
	var plan := CrossingPlan.new()
	plan.length_s = rng.randf_range(route.duration_s.x, route.duration_s.y)
	var margin: float = tuning.event_margin_s
	var weather := sky.weather
	if weather.pending != null and weather.pending.id == &"squall":
		plan._add(weather.pending_in_s, CrossingBeat.Kind.SQUALL)
	elif weather.current != null and weather.current.id == &"squall" and weather.current_left_s > 0.0:
		plan._add(tuning.running_squall_grace_s, CrossingBeat.Kind.SQUALL)
	elif weather.pending == null:
		plan._roll_own_squall(route, sky, rng, tuning)
	var shark_chance: float = tuning.shark_chance.get(band, 0.0) * route.shark_multiplier * route.threat_multiplier
	var rock_chance: float = tuning.rock_chance.get(band, 0.0) * route.threat_multiplier
	var latest: float = maxf(plan.length_s - margin, margin)
	if rng.randf() < shark_chance:
		plan._add(rng.randf_range(margin, latest), CrossingBeat.Kind.SHARK_PASS)
	if rng.randf() < rock_chance:
		plan._add(rng.randf_range(margin, latest), CrossingBeat.Kind.ROCK)
	plan._sort()
	return plan


## Events with from_s < time <= to_s, in time order.
func due(from_s: float, to_s: float) -> Array[RefCounted]:
	var list: Array[RefCounted] = []
	for item: RefCounted in events:
		var event := item as CrossingBeat
		if event.time_s > from_s and event.time_s <= to_s:
			list.append(event)
	return list


func to_array() -> Array:
	var list: Array = []
	for item: RefCounted in events:
		list.append((item as CrossingBeat).to_array())
	return [length_s, list]


## Null for malformed data (a client never trusts what arrives).
static func from_array(data: Variant) -> CrossingPlan:
	if not data is Array or (data as Array).size() != 2:
		return null
	var pair: Array = data
	if not (pair[0] is float or pair[0] is int) or not pair[1] is Array or not is_finite(float(pair[0])):
		return null
	var plan := CrossingPlan.new()
	plan.length_s = float(pair[0])
	for raw: Variant in pair[1]:
		var event := CrossingBeat.from_array(raw)
		if event == null:
			return null
		plan.events.append(event)
	plan._sort()
	return plan


func _add(time_s: float, kind: CrossingBeat.Kind) -> void:
	events.append(CrossingBeat.create(time_s, kind))


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


func _sort() -> void:
	events.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return (a as CrossingBeat).time_s < (b as CrossingBeat).time_s)
