extends GutTest
## island-pressure task 6.1, 1 player, offline: design D9's policy played against the pure rules over a
## scripted sandbar day. Walking times come from the sandbar layout (walk distances at walking speed),
## the build from raft.tres (its stages, time and work costs), the meters from survival_tuning.tres
## through SurvivalMeters, and the launch from LaunchSight with the patrol boat posed on its loop by its
## own clock. The real-shell measurement is tests/manual/island_pressure_run.gd; this keeps the targets
## in CI: midday seen, thirst under 50 before the launch, the launch at 20:00 or later, no death.

const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const STEP_S: float = 0.1
const WALK_TILES_S: float = MovementModel.WALK_SPEED
const PICK_S: float = 0.2
const EAT_S: float = 2.0
const LAUNCH_HOLD_S: float = 1.0
const LOW_THIRST: float = 30.0
const HOT: float = 80.0
const COOL: float = 30.0
const FED: float = 20.0
const GULL_SAFE_TILES: float = 9.5
## Two in-game days: if the policy has not launched by then, something is wrong.
const GIVE_UP_S: float = 2.0 * DayClock.DAY_S

var built: IslandLayout
var recipe: RecipeData
var meters: SurvivalMeters
var clock_s: float = 0.0
var at: Vector2i
var shaded: bool = false
var crafting: bool = false
var min_thirst: float = 100.0
var midday_seen: bool = false
var pickups: Array[Dictionary] = []
var coconuts: Array[int] = []
var carried: Dictionary[StringName, int] = {}
var deposited: Dictionary[StringName, int] = {}
var work_s: float = 0.0
var eaten: int = 0
# The patrol, posed by hand from its loop.
var patrol: PatrolData
var loop: PatrolLoop
var light: Searchlight
var boat: Creature
var calm: WeatherData


func before_each() -> void:
	built = IslandLayout.build(SANDBAR)
	recipe = GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	meters = autofree(SurvivalMeters.new()) as SurvivalMeters
	meters.solo = true
	clock_s = 0.0
	at = built.solo_spawn
	pickups = built.pickups.duplicate(true)
	coconuts = built.palm_coconuts.duplicate()
	var boat_data := GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData
	patrol = boat_data.patrol
	loop = PatrolLoop.build(built.terrain, built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	light = Searchlight.from_patrol(patrol)
	boat = autofree(Creature.make(boat_data)) as Creature
	calm = GameState.content.get_entry(&"weather", &"calm") as WeatherData


# --- the world, by hand ------------------------------------------------------------------------

func _phase() -> DataEnums.DayPhase:
	return DayClock.phase_at(fposmod(clock_s, DayClock.DAY_S))


func _midday() -> bool:
	var t: float = fposmod(clock_s, DayClock.DAY_S)
	return t >= DayClock.MIDDAY_START_S and t < DayClock.MIDDAY_END_S


# Time passes: the meters tick in the context the player is in.
func _spend(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		var context := MeterContext.new()
		context.phase = _phase()
		context.midday = _midday()
		context.shaded = shaded
		context.crafting = crafting
		meters.tick(STEP_S, context)
		clock_s += STEP_S
		min_thirst = minf(min_thirst, meters.thirst)
		midday_seen = midday_seen or _midday()


func _walk(to: Vector2i) -> void:
	var distances := built.walk_distances_from(at)
	assert_true(distances.has(to), "%s reachable from %s" % [to, at])
	shaded = false
	_spend(float(distances.get(to, 0)) / WALK_TILES_S)
	at = to
	shaded = built.hut_cells.has(to) and built.terrain.is_shaded(to)


func _nearest(cells: Array[Vector2i]) -> Vector2i:
	var distances := built.walk_distances_from(at)
	var best: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in cells:
		if distances.has(cell) and (best.x < 0 or distances[cell] < distances[best]):
			best = cell
	return best


func _pick_up(item_id: StringName) -> bool:
	var cells: Array[Vector2i] = []
	for entry: Dictionary in pickups:
		if entry["item_id"] == item_id and int(entry["count"]) > 0:
			cells.append(entry["cell"])
	if cells.is_empty():
		return false
	var cell := _nearest(cells)
	_walk(cell)
	for entry: Dictionary in pickups:
		if entry["cell"] == cell and entry["item_id"] == item_id and int(entry["count"]) > 0:
			entry["count"] = int(entry["count"]) - 1
			break
	carried[item_id] = carried.get(item_id, 0) + 1
	_spend(PICK_S)
	return true


# --- the stages, from raft.tres ----------------------------------------------------------------

func _stage_end_s(index: int) -> float:
	var total: float = 0.0
	for i: int in index + 1:
		total += recipe.stages[i].time_s
	return total


func _stage() -> int:
	for i: int in recipe.stages.size():
		if _stage_end_s(i) > work_s + 0.0001:
			return i
	return recipe.stages.size() - 1


func _stage_missing() -> Dictionary[StringName, int]:
	var need: Dictionary[StringName, int] = {}
	for i: int in _stage() + 1:
		for id: StringName in recipe.stages[i].inputs:
			need[id] = need.get(id, 0) + recipe.stages[i].inputs[id]
	var missing: Dictionary[StringName, int] = {}
	for id: StringName in need:
		if deposited.get(id, 0) < need[id]:
			missing[id] = need[id] - deposited.get(id, 0)
	return missing


func _deposit() -> void:
	for id: StringName in carried.keys():
		var take: int = mini(carried[id], recipe.inputs.get(id, 0) - deposited.get(id, 0))
		if take > 0:
			deposited[id] = deposited.get(id, 0) + take
			carried[id] -= take


# Holds the site, second by second at its costs, until the stage's end, a need, or the build is done.
func _work() -> void:
	_walk(built.raft_site)
	_deposit()
	var stop_s: float = _stage_end_s(_stage())
	crafting = true
	while work_s < recipe.time_s - 0.0001 and _stage_missing().is_empty():
		if meters.energy <= 0.000001 or meters.thirst < LOW_THIRST or (meters.heat >= HOT and _midday()):
			break
		var step: float = minf(STEP_S, meters.energy / recipe.work_energy_per_s)
		meters.spend_energy(recipe.work_energy_per_s * step)
		meters.add(DataEnums.Meter.THIRST, -recipe.work_thirst_per_s * step)
		_spend(STEP_S)
		work_s = minf(work_s + step, recipe.time_s)
		if work_s >= stop_s - 0.0001:
			stop_s = _stage_end_s(_stage())
	crafting = false


# --- coconuts, shade -----------------------------------------------------------------------------

func _coconut_left() -> bool:
	for count: int in coconuts:
		if count > 0:
			return true
	return carried.get(&"coco", 0) > 0


func _eat_coconut() -> bool:
	if carried.get(&"coco", 0) == 0:
		var best: int = -1
		var distances := built.walk_distances_from(at)
		for i: int in built.palms.size():
			if coconuts[i] <= 0 or not distances.has(built.palms[i]):
				continue
			var score: int = distances[built.palms[i]] + (100000 if SANDBAR.nest_palms.has(i) else 0)
			if best < 0 or score < distances.get(built.palms[best], 0) + (100000 if SANDBAR.nest_palms.has(best) else 0):
				best = i
		if best < 0:
			return false
		_walk(built.palms[best])
		_spend(2.0)
		for effect: EffectData in SANDBAR.climb_effects:
			meters.add(effect.meter, effect.amount)
		coconuts[best] -= 1
		carried[&"coco"] = 1
		if not _gull_safe(at):
			_walk(_safe_cell())
	carried[&"coco"] = carried.get(&"coco", 0) - 1
	var coco := GameState.content.get_entry(&"items", &"coco") as ItemData
	for effect: EffectData in coco.uses[0].effects:
		if effect.meter == DataEnums.Meter.HUNGER:
			meters.eat(effect.amount)
		else:
			meters.add(effect.meter, effect.amount)
	eaten += 1
	_spend(EAT_S)
	return true


func _gull_safe(cell: Vector2i) -> bool:
	for i: int in SANDBAR.nest_palms:
		if Vector2(cell).distance_to(Vector2(built.palms[i])) <= GULL_SAFE_TILES:
			return false
	return true


func _safe_cell() -> Vector2i:
	var distances := built.walk_distances_from(at)
	var best: Vector2i = at
	for cell: Vector2i in distances:
		if _gull_safe(cell) and (not _gull_safe(best) or distances[cell] < distances[best]):
			best = cell
	return best


func _shade_cell() -> Vector2i:
	var shade: Array[Vector2i] = []
	for cell: Vector2i in built.hut_cells:
		if built.terrain.is_shaded(cell):
			shade.append(cell)
	return _nearest(shade)


# Handles the first need that applies; true when one did.
func _needs() -> bool:
	if meters.thirst < LOW_THIRST and _coconut_left():
		return _eat_coconut()
	if meters.energy <= 0.000001 and _coconut_left():
		while meters.energy < FED and _coconut_left():
			if not _eat_coconut():
				break
		return true
	if meters.heat >= HOT and _midday():
		_walk(_shade_cell())
		while meters.heat >= COOL:
			_spend(1.0)
		return true
	return false


# --- the launch ----------------------------------------------------------------------------------

# The boat posed from its own clock at this time (boat 0 of 1), as PatrolRoute would pose it.
func _seen() -> bool:
	var period: float = PatrolLoop.period_s(patrol)
	var boat_clock: float = PatrolLoop.boat_clock(clock_s, 0, 1, period)
	var lap: bool = PatrolLoop.phase_at(boat_clock, period, patrol.horizon_warning_s, patrol.route_lap_s) == PatrolLoop.Phase.LAP
	boat.state_id = PatrolRoute.State.LAP if lap else PatrolRoute.State.AWAY
	var lap_t: float = PatrolLoop.lap_time(boat_clock, patrol.horizon_warning_s)
	var pose: Vector2 = loop.pose_at(lap_t) if lap else loop.pose_at(0.0)
	boat.position = pose * 16.0
	boat.beam = light.beam_deg(pose, loop.centroid, lap_t) if lap else 0.0
	boat.light_on = lap and light.is_on(_phase(), calm.disabled_senses)
	var typed: Array[Creature] = [boat]
	return LaunchSight.seen_by(typed, _phase(), calm, IslandLayout.cell_center(built.raft_site)) != null


func test_the_policy_spends_a_day_on_the_sandbar() -> void:
	assert_true(_pick_up(&"knife"), "the hut's knife")
	while work_s < recipe.time_s - 0.0001 and clock_s < GIVE_UP_S:
		if _needs():
			continue
		if meters.energy <= 0.000001:
			break
		var missing := _stage_missing()
		var wanted: StringName = &""
		for id: StringName in missing:
			if carried.get(id, 0) < missing[id]:
				wanted = id
				break
		if wanted != &"":
			assert_true(_pick_up(wanted), "the sandbar holds %s" % wanted)
			continue
		_work()
	assert_almost_eq(work_s, recipe.time_s, 0.001, "the raft is built")
	gut.p("built at %.0f s (%02d:%02d), energy %.1f, thirst %.1f, coconuts eaten %d" % [clock_s, 6 + int(clock_s / 30.0) % 24, int(fposmod(clock_s, 30.0) * 2.0), meters.energy, meters.thirst, eaten])
	while clock_s < GIVE_UP_S:
		if meters.energy < FED and _coconut_left():
			_eat_coconut()
			continue
		if _needs():
			continue
		if not _seen():
			break
		if at != _shade_cell():
			_walk(_shade_cell())
		_spend(1.0)
	_walk(built.raft_site)
	while _seen() and clock_s < GIVE_UP_S:
		_spend(1.0)
	_spend(LAUNCH_HOLD_S)
	var time_of_day: float = fposmod(clock_s, DayClock.DAY_S)
	gut.p("launch at %.0f s (%02d:%02d), thirst min %.1f, energy %.1f, thirst %.1f, coconuts eaten %d" % [clock_s, (6 + int(time_of_day / 30.0)) % 24, int(fposmod(time_of_day, 30.0) * 2.0), min_thirst, meters.energy, meters.thirst, eaten])
	assert_true(midday_seen, "midday seen on the sandbar")
	assert_lt(min_thirst, 50.0, "thirst under 50 before the launch")
	assert_gte(time_of_day, DayClock.NIGHT_START_S, "the launch at 20:00 or later")
	assert_lt(clock_s, DayClock.DAY_S, "on day 1")
	assert_false(meters.dead, "no death")
	assert_false(meters.last_stand, "not even close")
