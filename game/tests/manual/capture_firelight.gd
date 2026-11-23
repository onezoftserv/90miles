extends Node
## Manual check for art-mood-pass "Firelight at night" (design D2, task 2.5), run windowed (lights
## need a real renderer, so never headless and never in CI):
##   godot --path game res://tests/manual/capture_firelight.tscn -- --out=<dir>
## The real sandbar in a SubViewport under the day-night tint at night, a lit fire on the beach cell
## nearest the solo spawn with land all round it, and a player standing two cells east of it. Writes
## <dir>/firelight_night_x3.png: the fire's surroundings, 14 x 10 cells, enlarged ×3.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const LAYOUT_PATH: String = "res://resources/islands/sandbar.tres"
## Well into the night, past the 20 s blend.
const NIGHT_S: float = DayClock.NIGHT_START_S + 60.0
const SETTLE_FRAMES: int = 30
const VIEW_CELLS: Vector2i = Vector2i(14, 10)
const ZOOM: int = 3

var _out_dir: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("capture_firelight: pass --out=<dir>")
		get_tree().quit(1)
		return
	WeatherManager.stop()
	WeatherManager.sky.start_at(NIGHT_S)
	var layout := load(LAYOUT_PATH) as IslandLayoutData
	var built := IslandLayout.build(layout)
	var at: Vector2i = _fire_cell(built)
	var view_origin: Vector2i = at - VIEW_CELLS / 2
	var view := SubViewport.new()
	view.size = VIEW_CELLS * IslandLayout.TILE
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	island.with_creatures = false
	island.position = -Vector2(view_origin * IslandLayout.TILE)
	view.add_child(island)
	view.add_child(TINT_SCENE.instantiate())
	var fire := FIRE_SCENE.instantiate() as Fire
	fire.position = island.position + IslandLayout.cell_center(at)
	view.add_child(fire)
	fire.light()
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.local_player = false
	body.position = island.position + IslandLayout.cell_center(at + Vector2i(2, 0))
	view.add_child(body)
	body.camera.enabled = false
	(body.get_node(^"Look") as PlayerLook).process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var image := view.get_texture().get_image()
	image.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	image.save_png(_out_dir.path_join("firelight_night_x3.png"))
	print("capture_firelight: fire at %s, frame %.1f ms" % [at, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	get_tree().quit()


# The beach cell nearest the solo spawn whose eight neighbours are all beach, so the pool lies on sand.
func _fire_cell(built: IslandLayout) -> Vector2i:
	var best := Vector2i(-1, -1)
	for cell: Vector2i in built.terrain.cells:
		if not _all_beach(built, cell):
			continue
		if best.x < 0 or (cell - built.solo_spawn).length_squared() < (best - built.solo_spawn).length_squared():
			best = cell
	return best if best.x >= 0 else built.solo_spawn


func _all_beach(built: IslandLayout, cell: Vector2i) -> bool:
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			if built.terrain.terrain_at(cell + Vector2i(x, y)) != DataEnums.Terrain.BEACH:
				return false
	return true
