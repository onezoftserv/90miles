extends Node
## Manual capture for inventory-hud task 8.5, run windowed (it needs a real renderer, so never
## headless and never in CI). It starts a solo sandbar run at 1× (the window is the 640×360 base
## picture), sets each scene up by placing the player and setting its intent, and saves what the
## window shows:
##   godot --path game res://tests/manual/capture_inventory_hud.tscn -- --out=<dir>
## Writes <dir>/strip_selection.png (the strip with the coconut selected), prompt_ring.png (a palm
## climb halfway, its ring half full), craft_list.png (the bench's list), hidden_day.png and
## hidden_night.png (a player crouching in the brush with the hidden mark, by day and at Noche).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_inventory_hud.cfg"
const SCALE: int = 1
const SETTLE_FRAMES: int = 30
## Half the sandbar's 2 s palm climb, at 60 physics frames a second.
const HALF_CLIMB_FRAMES: int = 60
## weather-daynight: 200 s after dawn is day, 440.1 s is Noche.
const DAY_S: float = 200.0
const NIGHT_S: float = 440.1
const AT_BENCH: Vector2 = Vector2(0.0, 10.0)

var _out_dir: String = ""
var _shell: GameShell
var _body: PlayerBody


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless":
		push_error("capture_inventory_hud: run windowed and pass --out=<dir>")
		get_tree().quit(1)
		return
	_write_settings()
	_shell = SHELL_SCENE.instantiate() as GameShell
	_shell.settings_path = SETTINGS_PATH
	add_child(_shell)
	await _frames(5)
	_shell.start_solo()
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(DAY_S)
	_body = _shell.session.body(CoopSession.HOST_ID)
	_body.player_input.enabled = false
	await _capture_strip()
	await _capture_ring()
	await _capture_list()
	await _capture_hidden()
	_shell.back_to_title()
	get_tree().quit()


func _write_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", SCALE)
	config.set_value("display", "pixel_filter", 0)
	config.save(SETTINGS_PATH)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _place(at: Vector2) -> void:
	_body.global_position = at
	_body.camera.reset_smoothing()
	await _frames(SETTLE_FRAMES)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var window_size := DisplayFit.window_size(SCALE)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != window_size:
		image.resize(window_size.x, window_size.y, Image.INTERPOLATE_NEAREST)
	var path := _out_dir.path_join(file_name)
	print("capture_inventory_hud: %s (%s)" % [path, error_string(image.save_png(path))])


# The strip with a knife, coconuts, driftwood and rope, the coconut selected: "Coco · [F] Beber".
func _capture_strip() -> void:
	var inventory := _body.inventory
	inventory.add(&"knife", 1)
	inventory.add(&"coco", 3)
	inventory.add(&"driftwood", 4)
	inventory.add(&"rope", 2)
	inventory.add(&"dry_grass", 1)
	_shell.hud.strip.select(1)
	await _place(IslandLayout.cell_center(_shell.island.built.solo_spawn))
	await _save("strip_selection.png")


# Halfway up the nearest palm: "[E] Trepar Mata de coco" with its ring half full.
func _capture_ring() -> void:
	var palm := _shell.island.get_node(^"Palms").get_child(0) as Palm
	await _place(palm.global_position + Vector2(-6.0, 4.0))
	_body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await _physics_frames(HALF_CLIMB_FRAMES)
	await _save("prompt_ring.png")
	_body.intent = MoveIntent.new()
	await _frames(2)


# E at the hut's bench: the crafting list, "Fogata" highlighted with what it needs.
func _capture_list() -> void:
	var bench := _shell.session.get_node(^"HutWorkbench") as Workbench
	await _place(bench.global_position + AT_BENCH)
	_body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await _physics_frames(2)
	_body.intent = MoveIntent.new()
	await _frames(SETTLE_FRAMES)
	await _save("craft_list.png")
	_shell.hud.craft_list.close()
	await _frames(2)


# Crouching in the brush: the body drawn lower and the closed-eye mark, by day and at Noche.
func _capture_hidden() -> void:
	var cell := _brush_cell()
	_body.intent = MoveIntent.create(Vector2.ZERO, false, true)
	await _place(IslandLayout.cell_center(cell))
	await _save("hidden_day.png")
	WeatherManager.sky.start_at(NIGHT_S)
	await _frames(SETTLE_FRAMES)
	await _save("hidden_night.png")
	_body.intent = MoveIntent.new()


# The brush cell nearest the solo spawn point, one with brush all round it if there is one.
func _brush_cell() -> Vector2i:
	var built := _shell.island.built
	var terrain := _shell.island.terrain
	var best := Vector2i(-1, -1)
	var best_score: float = INF
	for y: int in range(1, built.size.y - 1):
		for x: int in range(1, built.size.x - 1):
			var cell := Vector2i(x, y)
			if not TerrainQuery.is_brush(terrain.terrain_at(cell)):
				continue
			var score: float = Vector2(cell).distance_to(Vector2(built.solo_spawn))
			if not _brush_around(terrain, cell):
				score += float(built.size.x + built.size.y)
			if score < best_score:
				best = cell
				best_score = score
	return best


func _brush_around(terrain: GridTerrain, cell: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not TerrainQuery.is_brush(terrain.terrain_at(cell + Vector2i(dx, dy))):
				return false
	return true
