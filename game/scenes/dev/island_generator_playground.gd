class_name IslandGeneratorPlayground
extends Node2D
## island-generator's dev scene ("Walking generated reefs alone"): one offline player on a generated
## island of `chain`, built the way a run builds it (the island scene, a solo CoopSession, its
## IslandTravel and the run HUD). Keys: N the next run seed, P the previous one, R regenerate the
## same island. The label shows the land cells, the attempts, whether the fallback was used, the
## lone walks from the first landing cell to the raft site and each POI, and the generation time.
## Start it with `godot --path game res://scenes/dev/island_generator_playground.tscn`; add
## `-- --timings` to print the generation time per attempt for run seeds 1–20. No port is opened.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const LOG_PREFIX: String = "island-generator:"
const TIMINGS_FLAG: String = "--timings"

## The chain the scene generates from.
@export var chain: ChainData = preload("res://resources/chains/reef_traps.tres")
## The run seed of the island shown.
@export var run_seed: int = 1
## The island index the chain is generated at.
@export var index: int = 3
## Off by default: with the reef's sharks and crabs spawned, quitting prints "resources still in
## use" for the creature data (not traced yet; see design.md "Changes from the build plan").
@export var with_creatures: bool = false

var session: CoopSession = null
var travel: IslandTravel = null
var hud: RunHud = null
var label: Label = null
## The island shown, as the generator returned it.
var generated: GeneratedIsland = null


func _ready() -> void:
	y_sort_enabled = true
	NetManager.start_solo()
	var first := ISLAND_SCENE.instantiate() as SandbarIsland
	first.layout = _generate().layout
	first.with_creatures = with_creatures
	add_child(first)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = first.terrain
	session.climate = first.climate
	session.sky = WeatherManager.sky
	session.spawn_points = first.spawn_points(true)
	session.world_state["run_seed"] = run_seed
	add_child(session)
	first.furnish(session)
	travel = IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	WeatherManager.sky.start_at(0.0)
	session.start()
	travel.setup(session, first)
	travel.history.entries.clear()
	travel.history.arrive(chain.id, index, false)
	first.place_pickups(session)
	WeatherManager.start(0.0)
	hud = HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	hud.bind(session, session.multiplayer.get_unique_id(), true)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	label = Label.new()
	label.position = Vector2(4, 4)
	layer.add_child(label)
	_land_on_first_cell()
	_show()
	if OS.get_cmdline_user_args().has(TIMINGS_FLAG):
		log_timings(1, 20)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_N:
			step(1)
		KEY_P:
			step(-1)
		KEY_R:
			regenerate()


## Shows the island of run seed `run_seed + by`.
func step(by: int) -> void:
	run_seed += by
	_load()


## Generates the shown island again, from nothing cached.
func regenerate() -> void:
	IslandSource.clear_cache()
	_load()


## Prints the generation time per attempt for run seeds `from` to `to`.
func log_timings(from: int, to: int) -> void:
	for at: int in range(from, to + 1):
		var island: GeneratedIsland = IslandGenerator.generate(at, index, chain)
		var ms: float = island.report["generation_ms"]
		log_line("run seed %d: %d attempts, %.1f ms, %.1f ms per attempt" % [at, island.attempts, ms, ms / island.attempts])


func log_line(line: String) -> void:
	print("%s %s" % [LOG_PREFIX, line])


## The label's text: land cells, attempts, fallback, the walks and the generation time.
func summary() -> String:
	var lines := PackedStringArray()
	lines.append("%s %d, run seed %d" % [chain.id, index, run_seed])
	lines.append("land cells %d, attempts %d, fallback %s" % [generated.report["land_count"], generated.attempts, "yes" if generated.fallback else "no"])
	var walks: Dictionary = walks_of(generated)
	for what: String in walks:
		lines.append("walk to %s: %.1f s" % [what, walks[what]])
	lines.append("generated in %.1f ms" % generated.report["generation_ms"])
	lines.append("N next seed, P previous, R regenerate")
	return "\n".join(lines)


## Seconds a lone walker needs from the first landing cell to the raft site and each POI anchor.
static func walks_of(island: GeneratedIsland) -> Dictionary:
	var built: IslandLayout = island.built
	var grid := IslandGrid.new(built.size.x, built.size.y)
	var terrain := grid.filled(DataEnums.Terrain.DEEP)
	for cell: Vector2i in built.terrain.cells:
		terrain[grid.index_of(cell)] = built.terrain.cells[cell]
	var walk: PackedInt32Array = grid.chamfer_walk(grid.mask_of(terrain, IslandLayout.WALKABLE), built.landing_cells()[0])
	var walks: Dictionary = {}
	walks["raft site"] = walk[grid.index_of(built.raft_site)] / PoiPlacer.HALF_TILES_PER_S
	for placed: Dictionary in island.pois:
		walks[String(placed["id"])] = walk[grid.index_of(placed["anchor"])] / PoiPlacer.HALF_TILES_PER_S
	return walks


func _generate() -> GeneratedIsland:
	generated = IslandSource.generated_island(chain, index, run_seed, GameState.content)
	return generated


func _load() -> void:
	session.world_state["run_seed"] = run_seed
	_generate()
	var body := session.body(session.multiplayer.get_unique_id())
	var arrivals: Dictionary = {session.multiplayer.get_unique_id(): {"health": body.meters.health, "energy": body.meters.energy}}
	travel._load(chain.id, arrivals, 0.0, index, generated.island_hash)
	_show()


func _land_on_first_cell() -> void:
	var body := session.body(session.multiplayer.get_unique_id())
	if body != null:
		IslandArrival.land(body, IslandLayout.cell_center(travel.island.built.landing_cells()[0]), travel.island.terrain)
		IslandArrival.fit_camera(body, travel.island.bounds)


func _show() -> void:
	label.text = summary()
	log_line(summary().replace("\n", "; "))


# The cache's islands hold resources; nothing should outlive the scene.
func _exit_tree() -> void:
	WeatherManager.stop()
	IslandSource.clear_cache()
