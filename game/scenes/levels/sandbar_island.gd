class_name SandbarIsland
extends Node2D
## A handmade island (island-generation "Handmade sandbar", "Handmade coast cay" and "Any handmade
## layout builds the island"), built from the layout it is given: the grid, the palms, the
## workbench, the lagoon, the signs and the pick-ups. Its `Terrain` child (TerrainView) draws the
## ground from the grid on every peer and only reads it. The layout is set before the island enters
## the tree (the sandbar is the default). Terrain, palms, workbench, drinking spots and signs are
## built on every peer from the same data; the pick-ups are placed and refreshed by the host alone,
## through the session's pick-up spawner. The class keeps its name from the first island. The
## shelter `shelter_art.tres` names for the layout (the sandbar's lean-to) stands over the hut on
## every peer, drawing only.

const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")
const SHELTER_NAME: StringName = &"Shelter"
const BENCH_NAME: StringName = &"HutWorkbench"
const ROUTES_NAME: StringName = &"Routes"
const CREATURES_NAME: StringName = &"Creatures"
const RAFT_SITE_NAME: StringName = &"RaftSite"
const RAFT_NAME: StringName = &"Raft"
const RAFT_RECIPE_ID: StringName = &"raft"
const SQUALL_ID: StringName = &"squall"
const DRINK_SPOT_NAME: String = "DrinkSpot%d"
const SIGN_NAME: String = "Sign%d"
const RAFT_SCENE: PackedScene = preload("res://scenes/structures/raft.tscn")

## The island to build. Setting it rebuilds the terrain, bounds and lists below, so set it before
## the island enters the tree.
@export var layout: IslandLayoutData = preload("res://resources/islands/sandbar.tres"):
	set(value):
		layout = value
		_rebuild()

## Off only in tests that count pick-ups or inventories; the run keeps its crabs, gulls and shark.
var with_creatures: bool = true
var built: IslandLayout = IslandLayout.build(layout)
var terrain: GridTerrain = built.terrain
## The game's one sky's climate (weather-daynight); the session and the bodies read it.
var climate: ClimateState = WeatherManager.sky.climate
## The island in pixels: the run camera stays inside it.
var bounds: Rect2i = Rect2i(Vector2i.ZERO, built.size * IslandLayout.TILE)

var _session: CoopSession
var _weather_id: StringName = &""
## Host: each placed pick-up's spec and its node (null, or freed, once taken).
var _placed: Array[Dictionary] = []


# The member initialisers above build the default layout; this is the same reading for another one.
func _rebuild() -> void:
	built = IslandLayout.build(layout)
	terrain = built.terrain
	bounds = Rect2i(Vector2i.ZERO, built.size * IslandLayout.TILE)


func _ready() -> void:
	# Y-sorted like the island root and the World above it, so each palm sorts by its trunk base
	# with the players, creatures and pick-ups (art-pass "Draw order by foot position").
	var palms := Node2D.new()
	palms.name = "Palms"
	palms.y_sort_enabled = true
	add_child(palms)
	for i: int in built.palms.size():
		var palm := PALM_SCENE.instantiate() as Palm
		palm.position = IslandLayout.cell_center(built.palms[i])
		palm.coconuts = built.palm_coconuts[i]
		palm.climb_effects = layout.climb_effects
		palm.hold_s = layout.climb_hold_s
		palms.add_child(palm)
	_place_shelter()


# The layout's shelter, if the art data names one, with its origin on the hut's back edge (the top
# edge of the hut's northmost row), centred on the hut, so it sorts with the palms and the session.
func _place_shelter() -> void:
	var scene: PackedScene = ShelterArtData.standard().shelter_for(layout.id)
	if scene == null or built.hut_cells.is_empty():
		return
	var west: int = built.hut_cells[0].x
	var east: int = west
	var back: int = built.hut_cells[0].y
	for cell: Vector2i in built.hut_cells:
		west = mini(west, cell.x)
		east = maxi(east, cell.x)
		back = mini(back, cell.y)
	var shelter := scene.instantiate() as Node2D
	shelter.name = SHELTER_NAME
	shelter.position = Vector2((west + east + 1) * IslandLayout.TILE / 2.0, back * IslandLayout.TILE)
	add_child(shelter)


func _exit_tree() -> void:
	if WeatherManager.weather_changed.is_connected(_on_weather_changed):
		WeatherManager.weather_changed.disconnect(_on_weather_changed)


## Where players appear: the solo spawn point near the hut, or the co-op ones in join order.
func spawn_points(solo: bool) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if solo:
		points.append(IslandLayout.cell_center(built.solo_spawn))
		return points
	for cell: Vector2i in built.coop_spawns:
		points.append(IslandLayout.cell_center(cell))
	return points


## Every peer: the workbench (when the layout has one), the routes, the raft's build site, the
## drinking spots and the signs go in the session at the same path on each, and the island starts
## listening for squalls to end. The host also starts the creatures, unless the layout is off-graph.
func furnish(session: CoopSession) -> void:
	_session = session
	if built.workbench.x >= 0:
		var bench := Workbench.new()
		bench.name = BENCH_NAME
		bench.position = IslandLayout.cell_center(built.workbench)
		session.add_child(bench)
	_place_water_and_signs()
	var routes := IslandRoutes.new()
	routes.name = ROUTES_NAME
	session.add_child(routes)
	routes.setup(session, layout.route_ids)
	routes.route_started.connect(_on_route_started)
	_place_raft_site()
	# An off-graph layout (the secret cay) never gets creatures (island-generation "Any handmade
	# layout builds the island").
	if with_creatures and not layout.off_graph:
		_place_creatures()
	_weather_id = WeatherManager.weather_id()
	WeatherManager.weather_changed.connect(_on_weather_changed)


# The lagoon's shore and the flavour signs, named by their order in the layout.
func _place_water_and_signs() -> void:
	for index: int in built.drink_spots.size():
		var spot := DrinkSpot.new()
		spot.name = DRINK_SPOT_NAME % index
		spot.position = IslandLayout.cell_center(built.drink_spots[index])
		spot.hold_time_s = layout.drink_hold_s
		spot.effects = layout.drink_effects
		_session.add_child(spot)
	for index: int in built.signs.size():
		var data := built.signs[index]["sign"] as IslandSignData
		var marker := IslandSign.new()
		marker.name = SIGN_NAME % index
		marker.position = IslandLayout.cell_center(built.signs[index]["cell"])
		marker.line_es = data.text_es
		marker.line_en = data.text_en
		_session.add_child(marker)


## Every peer: a raft that ended its crossing intact lies on the build site with the integrity it
## has left, and can be launched again. The empty site it replaces goes. Nothing for a broken raft
## or a layout with no site.
func beach_raft(integrity: float) -> void:
	if built.raft_site.x < 0 or integrity <= 0.0 or _session == null:
		return
	var site := _session.get_node_or_null(NodePath(RAFT_SITE_NAME))
	if site != null:
		_session.remove_child(site)
		site.queue_free()
	var raft := RAFT_SCENE.instantiate() as Raft
	raft.name = RAFT_NAME
	raft.climate = climate
	raft.position = IslandLayout.cell_center(built.raft_site)
	_session.add_child(raft)
	raft.on_built(GameState.content.get_entry(&"recipes", RAFT_RECIPE_ID) as RecipeData)
	# on_built gives the recipe's full integrity: the beached raft has what the crossing left.
	raft.integrity = integrity


# Host: the creature spawner runs the island's crabs, gulls and shark. Clients only receive them.
func _place_creatures() -> void:
	var spawner := CreatureSpawner.new()
	spawner.name = CREATURES_NAME
	spawner.auto_party = true
	_session.add_child(spawner)
	spawner.setup(_session, layout)
	spawner.start()


# A fresh, empty site for the raft (named the same on every peer; the built raft takes the name Raft).
func _place_raft_site() -> void:
	if built.raft_site.x < 0:
		return
	var site := preload("res://scenes/structures/build_site.tscn").instantiate() as BuildSite
	site.name = RAFT_SITE_NAME
	site.recipe = GameState.content.get_entry(&"recipes", RAFT_RECIPE_ID) as RecipeData
	site.climate = climate
	site.synced = true
	site.structure_name = RAFT_NAME
	site.position = IslandLayout.cell_center(built.raft_site)
	_session.add_child(site)


# A launched raft is used up and a fresh site takes its place, so whoever stays can build again.
func _on_route_started(route_id: StringName, _peer_ids: Array[int]) -> void:
	if route_id != RAFT_RECIPE_ID:
		return
	var raft := _session.get_node_or_null(NodePath(RAFT_NAME))
	if raft != null:
		_session.remove_child(raft)
		raft.queue_free()
	_place_raft_site()


## Host: lays down every pick-up, one per placed entry, carrying the entry's count.
func place_pickups(session: CoopSession) -> void:
	for spec: Dictionary in built.pickups:
		_placed.append({"spec": spec, "node": null})
	_refill(session, true)


# Puts back every taken pick-up of `spec` that comes back (all of them on the first call).
func _refill(session: CoopSession, everything: bool) -> void:
	for entry: Dictionary in _placed:
		var spec: Dictionary = entry["spec"]
		var node: Variant = entry["node"]
		var lying: bool = is_instance_valid(node) and not (node as Node).is_queued_for_deletion()
		if lying or not everything and spec["respawn"] != DataEnums.RespawnTrigger.SQUALL:
			continue
		entry["node"] = session.spawn_pickup(spec["item_id"], spec["count"], IslandLayout.cell_center(spec["cell"]))


func _on_weather_changed(weather_id: StringName) -> void:
	var was: StringName = _weather_id
	_weather_id = weather_id
	if was != SQUALL_ID or weather_id == SQUALL_ID:
		return
	if is_instance_valid(_session) and _session.multiplayer.is_server():
		_refill(_session, false)

