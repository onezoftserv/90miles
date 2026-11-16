extends Node
## Manual check for art-pass "The sandbar's creatures" and art-sprite-polish D6 and D7, run
## windowed (it needs a real renderer, so never headless and never in CI):
##   godot --path game res://tests/manual/capture_creatures.tscn -- --out=<dir>
## On the real sandbar, beside a standing player, it shows a crab standing, one scuttling east, one
## pinching and one stealing, and a gull swooping south over the sand, enlarged x6; then the same
## crabs at night under the day-night tint. Writes <dir>/creatures_day.png and creatures_night.png.
## Nothing simulates: the bodies' processing is off; only their looks read the states set here,
## and the walkers are moved a pixel a frame by this script.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
const LAYOUT_PATH: String = "res://resources/islands/sandbar.tres"
const ZOOM: int = 6
const SETTLE_FRAMES: int = 40
## Night: a quarter of the way into the night phase, past the dusk blend.
const NIGHT_S: float = DayClock.NIGHT_START_S + 75.0
## The cells round the first beach cell the capture spans, and where each actor stands in them.
const SPAN: Vector2i = Vector2i(9, 5)
const PLAYER_AT: Vector2i = Vector2i(1, 2)
## NightThief: WANDER, ..., STEAL 2, PINCH 4. SwoopSteal: SWOOP 1.
const CRABS: Array[Array] = [[Vector2i(3, 2), 0, false], [Vector2i(4, 3), 0, true], [Vector2i(6, 2), 4, false], [Vector2i(7, 3), 2, false]]
const GULL_AT: Vector2i = Vector2i(5, 1)
const GULL_SWOOP: int = 1

var _out_dir: String = ""
var _walkers: Array[Node2D] = []
var _walk: Array[Vector2] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("capture_creatures: pass --out=<dir>")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	WeatherManager.stop()
	await _capture("creatures_day", false)
	WeatherManager.sky.start_at(NIGHT_S)
	await _capture("creatures_night", true)
	get_tree().quit()


func _process(_delta: float) -> void:
	for i: int in _walkers.size():
		if is_instance_valid(_walkers[i]):
			_walkers[i].position += _walk[i]


func _capture(capture: String, night: bool) -> void:
	var layout := load(LAYOUT_PATH) as IslandLayoutData
	var built: IslandLayout = IslandLayout.build(layout)
	var origin: Vector2i = _beach_block(built)
	var view := SubViewport.new()
	view.size = SPAN * IslandLayout.TILE
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	island.with_creatures = false
	island.position = -Vector2(origin * IslandLayout.TILE)
	view.add_child(island)
	if night:
		view.add_child(TINT_SCENE.instantiate())
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.local_player = false
	body.position = Vector2(PLAYER_AT * IslandLayout.TILE) + Vector2(8.0, 8.0)
	view.add_child(body)
	body.camera.enabled = false
	(body.get_node(^"Look") as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	_walkers.clear()
	_walk.clear()
	for crab: Array in CRABS:
		var walker: Node2D = _creature(view, &"land_crab", crab[0], crab[1])
		if crab[2]:
			_walkers.append(walker)
			_walk.append(Vector2(0.25, 0.0))
	if not night:
		var gull: Node2D = _creature(view, &"seagull", GULL_AT, GULL_SWOOP)
		_walkers.append(gull)
		_walk.append(Vector2(0.0, 0.2))
	await _frames(SETTLE_FRAMES)
	var image := view.get_texture().get_image()
	image.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	image.save_png(_out_dir.path_join(capture + ".png"))
	print("capture_creatures: %s" % capture)
	view.queue_free()
	await _frames(2)


func _creature(view: SubViewport, id: StringName, cell: Vector2i, state: int) -> Node2D:
	var data := GameState.content.get_entry(&"creatures", id) as CreatureData
	var creature := Creature.make(data)
	creature.process_mode = Node.PROCESS_MODE_DISABLED
	creature.position = Vector2(cell * IslandLayout.TILE) + Vector2(8.0, 8.0)
	creature.state_id = state
	view.add_child(creature)
	var look := creature.get_node_or_null(^"Look")
	if look != null:
		look.process_mode = Node.PROCESS_MODE_ALWAYS
	return creature


# The top-left cell of the first SPAN block of the sandbar that is all beach.
func _beach_block(built: IslandLayout) -> Vector2i:
	for y: int in built.size.y - SPAN.y:
		for x: int in built.size.x - SPAN.x:
			var ok: bool = true
			for dy: int in SPAN.y:
				for dx: int in SPAN.x:
					if built.terrain.terrain_at(Vector2i(x + dx, y + dy)) != DataEnums.Terrain.BEACH:
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	push_error("capture_creatures: no all-beach block of %s on the sandbar" % SPAN)
	return built.solo_spawn


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
