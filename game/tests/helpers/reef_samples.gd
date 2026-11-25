class_name ReefSamples
extends RefCounted
## island-generator tests: generated reefs shared by every test script in the run, so the 200-seed
## loops generate each island once. Run seeds are 1–200 and the island index is 3.

const CHAIN_PATH: String = "res://resources/chains/reef_traps.tres"
const INDEX: int = 3
const SEEDS: int = 200

static var _cache: Dictionary[int, GeneratedIsland] = {}


static func chain() -> ChainData:
	return load(CHAIN_PATH) as ChainData


## Island 3 of the reef for `run_seed`, generated once per run.
static func island(run_seed: int) -> GeneratedIsland:
	if not _cache.has(run_seed):
		_cache[run_seed] = IslandGenerator.generate(run_seed, INDEX, chain())
	return _cache[run_seed]


## Islands for run seeds 1 to `count`.
static func islands(count: int = SEEDS) -> Array[GeneratedIsland]:
	var found: Array[GeneratedIsland] = []
	for run_seed: int in range(1, count + 1):
		found.append(island(run_seed))
	return found


## The island's terrain as an IslandGrid-indexed array.
static func terrain_of(built: IslandLayout) -> PackedInt32Array:
	var grid := IslandGrid.new(built.size.x, built.size.y)
	var terrain := grid.filled(DataEnums.Terrain.DEEP)
	for cell: Vector2i in built.terrain.cells:
		terrain[grid.index_of(cell)] = built.terrain.cells[cell]
	return terrain


## An AStarGrid2D over the island's walkable cells, as test_coast_cay_layout.gd builds it.
static func walk_grid(built: IslandLayout) -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, built.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	for y: int in built.size.y:
		for x: int in built.size.x:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not IslandLayout.WALKABLE.has(built.terrain.terrain_at(cell)))
	return astar


## Seconds a lone walker needs from `from` to `to` (Euclidean step lengths).
static func seconds(astar: AStarGrid2D, from: Vector2i, to: Vector2i) -> float:
	var path: PackedVector2Array = astar.get_point_path(from, to)
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total / MovementModel.WALK_SPEED


static func by_text(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
