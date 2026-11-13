extends Node
## Manual check for art-pass "Terrain tile layers", "Scrolling sea" and "Shoreline overlay", run
## windowed (it needs a real renderer, so never headless and never in CI). It builds the real
## SandbarIsland scene for the sandbar and the coast cay, each whole in a SubViewport the island's
## size, and saves them; then four captures of one stretch of the sandbar's shore a quarter second
## apart, enlarged ×4; the whole sandbar again under the night tint (task 4.6); then a solo run
## through the game shell at 2×, as the player sees it:
##   godot --path game res://tests/manual/capture_terrain.tscn -- --out=<dir>
## Writes <dir>/sandbar_day.png, coast_cay_day.png, shore_0.png … shore_3.png, sandbar_night.png
## and sandbar_game.png.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const LAYOUTS: Dictionary[String, String] = {
	"sandbar_day": "res://resources/islands/sandbar.tres",
	"coast_cay_day": "res://resources/islands/coast_cay.tres",
}
const SETTINGS_PATH: String = "user://capture_terrain.cfg"
const SETTLE_FRAMES: int = 30
## The shore stretch, in sandbar cells, and its enlargement.
const SHORE_CELLS: Rect2i = Rect2i(28, 18, 14, 8)
const SHORE_ZOOM: int = 4
const SHORE_SHOTS: int = 4
const SHORE_STEP_S: float = 0.25
## Night: a quarter of the way into the night phase, past the dusk blend (as capture_looks.gd).
const NIGHT_S: float = DayClock.NIGHT_START_S + 75.0

var _out_dir: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("capture_terrain: pass --out=<dir>")
		get_tree().quit(1)
		return
	WeatherManager.stop()
	var shore_view: SubViewport = null
	for capture: String in LAYOUTS:
		var view := _island_view(load(LAYOUTS[capture]) as IslandLayoutData)
		await _frames(SETTLE_FRAMES)
		_save(view.get_texture().get_image(), capture)
		if capture == "sandbar_day":
			shore_view = view
		else:
			view.queue_free()
	var shore_px := Rect2i(SHORE_CELLS.position * IslandLayout.TILE, SHORE_CELLS.size * IslandLayout.TILE)
	for shot: int in SHORE_SHOTS:
		var image := shore_view.get_texture().get_image().get_region(shore_px)
		image.resize(shore_px.size.x * SHORE_ZOOM, shore_px.size.y * SHORE_ZOOM, Image.INTERPOLATE_NEAREST)
		_save(image, "shore_%d" % shot)
		await get_tree().create_timer(SHORE_STEP_S).timeout
	WeatherManager.sky.start_at(NIGHT_S)
	shore_view.add_child(TINT_SCENE.instantiate())
	await _frames(SETTLE_FRAMES)
	_save(shore_view.get_texture().get_image(), "sandbar_night")
	shore_view.queue_free()
	await _game_view()
	get_tree().quit()


# The real island scene, alone in a viewport of its size: no session, no players, no creatures.
func _island_view(layout: IslandLayoutData) -> SubViewport:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = layout
	island.with_creatures = false
	var view := SubViewport.new()
	view.size = island.built.size * IslandLayout.TILE
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	view.add_child(island)
	return view


# A solo run at 2×, as the window shows it.
func _game_view() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.save(SETTINGS_PATH)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child(shell)
	await _frames(5)
	shell.start_solo()
	for peer_id: int in shell.session.peer_ids():
		shell.session.body(peer_id).player_input.enabled = false
	await _frames(SETTLE_FRAMES * 2)
	_save(get_viewport().get_texture().get_image(), "sandbar_game")


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(image: Image, capture: String) -> void:
	var path := _out_dir.path_join(capture + ".png")
	print("capture_terrain: %s (%s)" % [path, error_string(image.save_png(path))])
