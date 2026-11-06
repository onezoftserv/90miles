class_name SandbarIsland
extends Node2D
## The run's first island, el banco de arena (island-generation "Handmade sandbar"), built from
## its layout data: terrain and shade, the palms, the hut's workbench and the pick-ups. Terrain,
## palms and the workbench are built on every peer from the same data; the pick-ups are placed
## and refreshed by the host alone, through the session's pick-up spawner.

const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")
const BENCH_NAME: StringName = &"HutWorkbench"
const SQUALL_ID: StringName = &"squall"
const POOL_COLOR: Color = Color(0.45, 0.8, 0.85, 0.6)

@export var layout: IslandLayoutData = preload("res://resources/islands/sandbar.tres")

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


func _ready() -> void:
	var palms := Node2D.new()
	palms.name = "Palms"
	add_child(palms)
	for i: int in built.palms.size():
		var palm := PALM_SCENE.instantiate() as Palm
		palm.position = IslandLayout.cell_center(built.palms[i])
		palm.coconuts = built.palm_coconuts[i]
		palm.climb_effects = layout.climb_effects
		palm.hold_s = layout.climb_hold_s
		palms.add_child(palm)
	queue_redraw()


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


## Every peer: the hut's workbench goes in the session at the same path on each, and the
## island starts listening for squalls to end.
func furnish(session: CoopSession) -> void:
	_session = session
	var bench := Workbench.new()
	bench.name = BENCH_NAME
	bench.position = IslandLayout.cell_center(built.workbench)
	session.add_child(bench)
	_weather_id = WeatherManager.weather_id()
	WeatherManager.weather_changed.connect(_on_weather_changed)


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


func _draw() -> void:
	DevIslandTerrain.draw(self, terrain)
	for pool: Vector2i in built.tide_pools:
		draw_rect(Rect2(Vector2(pool * IslandLayout.TILE), Vector2(IslandLayout.TILE, IslandLayout.TILE)), POOL_COLOR)
