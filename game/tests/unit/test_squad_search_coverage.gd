extends GutTest
## guardacostas-capture, group 6 (task 6.3, design.md "The search, simulated"): the built SquadPlan and
## the soldiers' day sight over both handmade islands, with the shipped numbers. 100 seeded runs per
## island: three soldiers land at the beach nearest the boat on the island's east side, take the plan's
## points (here the last known position: no fire is lit) and then walk between random land cells at
## 3 tiles/s for 150 s (the 180 s search less the landing and the walk in), with the shared spot meter
## on a still player in the open. The share spotted is pinned within ±10 points of what the real plan
## measured: 50% and 52% (design.md's throwaway model said 66% and 54%). By rule: a hidden player more than 2 tiles
## from every searched point is never found, and from each island's solo landing, cover more than
## 2 tiles away is at most 13 steps from any cell.

const RUNS: int = 100
const SIM_S: float = 150.0
const DT: float = 0.1
const PIN_POINTS: float = 10.0
const MAX_COVER_STEPS: int = 13
const STEPS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
## The percentage of runs in which the still player in the open is spotted, measured with the real
## plan on 2026-11-15 (design.md "Changes from the build plan", group 6).
const SANDBAR_SHARE: float = 50.0
const COAST_SHARE: float = 52.0

var patrol: PatrolData


func before_all() -> void:
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol


class Soldier extends RefCounted:
	var at: Vector2 = Vector2.ZERO
	var facing: Vector2 = Vector2.RIGHT
	var path: PackedVector2Array = PackedVector2Array()
	var next: int = 0
	var goal: Vector2i = Vector2i(-1, -1)
	var on_point: bool = false
	var searching_s: float = -1.0


class Island extends RefCounted:
	var built: IslandLayout
	var grid: AStarGrid2D
	var landing: Vector2i
	var walk: Array[Vector2i] = []
	var open: Array[Vector2i] = []
	var hiding: Array[Vector2i] = []


func _island(id: StringName) -> Island:
	var made := Island.new()
	made.built = IslandLayout.build(GameState.content.get_entry(&"islands", id) as IslandLayoutData)
	made.grid = CreatureNav.build(made.built.terrain, made.built.size).land
	var loop := PatrolLoop.build(made.built.terrain, made.built.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	var east: Vector2 = loop.pose_at(0.0)
	for t: int in int(loop.lap_s):
		var pose: Vector2 = loop.pose_at(float(t))
		if pose.x > east.x:
			east = pose
	made.landing = SquadPlan.landing_cell(east, made.built.terrain.cells)
	var seen: Dictionary[Vector2i, bool] = {made.landing: true}
	var queue: Array[Vector2i] = [made.landing]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if not TerrainQuery.is_water(made.built.terrain.terrain_at(cell)):
			made.walk.append(cell)
			if _hides(made.built, cell):
				made.hiding.append(cell)
			else:
				made.open.append(cell)
		for step: Vector2i in CreatureNav.STEPS_4:
			var next: Vector2i = cell + step
			if not seen.has(next) and CreatureNav.is_open(made.grid, next):
				seen[next] = true
				queue.append(next)
	return made


# Scrub, mangrove or a roofed cell: where a player can hide.
func _hides(built: IslandLayout, cell: Vector2i) -> bool:
	var terrain: DataEnums.Terrain = built.terrain.terrain_at(cell)
	return terrain == DataEnums.Terrain.SCRUB or terrain == DataEnums.Terrain.MANGROVE or built.terrain.is_shaded(cell)


# One run: true when the still player in the open was spotted within SIM_S. `hidden_at` is a hiding
# cell more than 2 tiles from the last known position; finding it fails the rule check.
func _run(island: Island, seed_value: int, rule_breaks: Array[String]) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var last_known: Vector2i = island.walk[rng.randi_range(0, island.walk.size() - 1)]
	var player: Vector2 = SquadPlan.center(island.open[rng.randi_range(0, island.open.size() - 1)])
	var hidden: Vector2 = Vector2(-100.0, -100.0)
	for attempt: int in 20:
		var cell: Vector2i = island.hiding[rng.randi_range(0, island.hiding.size() - 1)]
		if SquadPlan.center(cell).distance_to(SquadPlan.center(last_known)) > patrol.point_search_tiles + 0.001:
			hidden = SquadPlan.center(cell)
			break
	var plan := SquadPlan.build(patrol, island.landing, [] as Array[Vector2i], last_known, island.walk, seed_value)
	var cone := SightCone.for_soldier(patrol, DataEnums.DayPhase.DAY)
	var meter := SpotMeter.from_patrol(patrol)
	var soldiers: Array[Soldier] = []
	for i: int in patrol.squad_size:
		var soldier := Soldier.new()
		soldier.at = SquadPlan.center(island.landing)
		soldiers.append(soldier)
	var spotted: bool = false
	for tick: int in roundi(SIM_S / DT):
		for i: int in soldiers.size():
			_step(island, plan, i, soldiers[i], hidden, rule_breaks)
		var seen: bool = false
		for soldier: Soldier in soldiers:
			seen = seen or cone.sees(player, soldier.at, soldier.facing)
		if not spotted and meter.step(seen, false, DT):
			spotted = true
	return spotted


func _step(island: Island, plan: SquadPlan, index: int, soldier: Soldier, hidden: Vector2, rule_breaks: Array[String]) -> void:
	if soldier.searching_s >= 0.0:
		soldier.searching_s += DT
		if soldier.searching_s >= plan.point_search_s - 0.000001:
			if plan.finds(soldier.goal, hidden):
				rule_breaks.append("found a hidden player %s from point %s" % [hidden, soldier.goal])
			plan.searched(index)
			soldier.searching_s = -1.0
			soldier.goal = Vector2i(-1, -1)
		return
	if soldier.goal == Vector2i(-1, -1):
		var point: SquadPlan.Point = plan.take_point(index)
		soldier.on_point = point != null
		soldier.goal = point.cell if point != null else plan.next_walk_cell()
		soldier.path = PackedVector2Array()
		for cell: Vector2 in island.grid.get_point_path(Vector2i(floori(soldier.at.x), floori(soldier.at.y)), soldier.goal):
			soldier.path.append(cell + Vector2(0.5, 0.5))
		soldier.next = 1 if soldier.path.size() > 1 else 0
	var move: float = (GameState.content.get_entry(&"creatures", &"shore_soldier") as CreatureData).speed_tiles_s * DT
	while move > 0.0 and soldier.next < soldier.path.size():
		var to: Vector2 = soldier.path[soldier.next] - soldier.at
		var length: float = to.length()
		if length <= move:
			soldier.at = soldier.path[soldier.next]
			soldier.next += 1
			move -= length
		else:
			soldier.at += to / length * move
			move = 0.0
		if length > 0.000001:
			soldier.facing = to / length
	if soldier.next >= soldier.path.size():
		if soldier.on_point:
			soldier.searching_s = 0.0
		else:
			soldier.goal = Vector2i(-1, -1)


func _share(id: StringName) -> float:
	var island := _island(id)
	var spotted: int = 0
	var breaks: Array[String] = []
	for k: int in RUNS:
		if _run(island, k + 1, breaks):
			spotted += 1
	assert_eq(breaks, [] as Array[String], "%s: a hidden player more than 2 tiles from every point is never found" % id)
	return float(spotted) / float(RUNS)


func test_the_sandbar_spots_a_still_player_in_the_open_as_measured() -> void:
	var share: float = _share(&"sandbar")
	gut.p("sandbar: %.0f%% of %d runs spotted (design.md's model: 66%%)" % [share * 100.0, RUNS])
	assert_almost_eq(share * 100.0, SANDBAR_SHARE, PIN_POINTS)


func test_the_coast_cay_spots_a_still_player_in_the_open_as_measured() -> void:
	var share: float = _share(&"coast_cay")
	gut.p("coast cay: %.0f%% of %d runs spotted (design.md's model: 54%%)" % [share * 100.0, RUNS])
	assert_almost_eq(share * 100.0, COAST_SHARE, PIN_POINTS)


# From every land cell reachable from the solo landing, the walking steps (8-connected over land) to
# the nearest hiding cell more than 2 tiles away.
func _cover_steps(id: StringName) -> Array[int]:
	var built := IslandLayout.build(GameState.content.get_entry(&"islands", id) as IslandLayoutData)
	var land: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in built.reachable_from(built.solo_spawn):
		if not TerrainQuery.is_water(built.terrain.terrain_at(cell)):
			land[cell] = true
	var steps: Array[int] = []
	for start: Vector2i in land:
		var seen: Dictionary[Vector2i, int] = {start: 0}
		var queue: Array[Vector2i] = [start]
		var head: int = 0
		var found: int = -1
		while head < queue.size() and found < 0:
			var cell: Vector2i = queue[head]
			head += 1
			if _hides(built, cell) and Vector2(cell - start).length() > patrol.point_search_tiles + 0.000001:
				found = seen[cell]
				break
			for step: Vector2i in STEPS_8:
				var next: Vector2i = cell + step
				if land.has(next) and not seen.has(next):
					seen[next] = seen[cell] + 1
					queue.append(next)
		steps.append(found)
	return steps


func test_cover_more_than_2_tiles_away_is_at_most_13_steps_from_any_cell() -> void:
	for id: StringName in [&"sandbar", &"coast_cay"]:
		var steps := _cover_steps(id)
		steps.sort()
		assert_false(steps.has(-1), "%s: cover is reachable from every cell" % id)
		gut.p("%s: steps to cover more than 2 tiles away: median %d, max %d" % [id, steps[steps.size() / 2], steps.back()])
		assert_lte(steps.back(), MAX_COVER_STEPS, "%s" % id)
