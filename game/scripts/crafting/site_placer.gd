class_name SitePlacer
extends RefCounted
## Where the host puts a build site chosen at a workbench (crafting-inventory "Placing a build
## site", inventory-hud design D8), and the site and structure nodes the session's entity spawner
## builds on every peer from a checked payload. Pure placement: the session supplies the terrain,
## the bench's cell and the spots already taken.

const TILE: float = PlayerBody.TILE_SIZE
## A structure or site this close to a cell's centre takes the cell.
const TAKEN_PX: float = TILE / 2.0
const SITE_SCENE_PATH: String = "res://scenes/structures/build_site.tscn"
const RECIPE_META: StringName = &"recipe_id"


## Whether the bench places `recipe`'s site: a build-site recipe whose output is a structure.
static func places(recipe: RecipeData) -> bool:
	return recipe != null and recipe.build_site and recipe.output_kind == RecipeData.OutputKind.STRUCTURE


## The cell under `at`.
static func cell_at(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


## The free cell nearest `at` among the cell under it and its neighbours: land the recipe allows
## (any land when it lists none), not `bench_cell`, with nothing of `taken` within half a tile of
## its centre. Empty when there is none; a tie goes to the first in reading order.
static func free_cell(at: Vector2, bench_cell: Vector2i, recipe: RecipeData, terrain: TerrainQuery, taken: Array[Vector2]) -> Array[Vector2i]:
	var here := cell_at(at)
	var best: Array[Vector2i] = []
	var best_distance: float = INF
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var cell := here + Vector2i(dx, dy)
			if not _fits(cell, bench_cell, recipe, terrain, taken):
				continue
			var distance: float = at.distance_squared_to(IslandLayout.cell_center(cell))
			if distance < best_distance:
				best_distance = distance
				best = [cell]
	return best


static func _fits(cell: Vector2i, bench_cell: Vector2i, recipe: RecipeData, terrain: TerrainQuery, taken: Array[Vector2]) -> bool:
	if cell == bench_cell:
		return false
	var ground: DataEnums.Terrain = terrain.terrain_at(cell)
	var allowed: bool = recipe.placement_terrain.has(ground)
	if recipe.placement_terrain.is_empty():
		allowed = not TerrainQuery.is_water(ground)
	if not allowed:
		return false
	var centre := IslandLayout.cell_center(cell)
	for spot: Vector2 in taken:
		if spot.distance_to(centre) < TAKEN_PX:
			return false
	return true


## An empty site of `recipe` named `site_name` at `at`, synced with the host and spawned (its
## completion goes through the session).
static func make_site(recipe: RecipeData, site_name: String, at: Vector2, climate: ClimateState) -> BuildSite:
	var site := (load(SITE_SCENE_PATH) as PackedScene).instantiate() as BuildSite
	site.name = site_name
	site.recipe = recipe
	site.position = at
	site.climate = climate
	site.synced = true
	site.spawned = true
	return site


## The finished structure of `recipe` named `structure_name` at `at`, a member of the finished
## structures by its recipe id. `lit` draws it as built (a client's fire shows itself lit; the
## host lights its own through `on_built`). Null when the recipe has no structure scene.
static func make_structure(recipe: RecipeData, structure_name: String, at: Vector2, climate: ClimateState, lit: bool) -> Node2D:
	var path: String = BuildSite.STRUCTURE_PATH % recipe.id
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var made: Node2D = scene.instantiate() as Node2D if scene != null else null
	if made == null:
		return null
	made.name = structure_name
	made.position = at
	made.set(&"climate", climate)
	made.set_meta(RECIPE_META, recipe.id)
	made.add_to_group(PlayerBody.STRUCTURE_GROUP)
	if lit:
		made.set(&"lit", true)
	return made
