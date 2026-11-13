extends Node
## Manual check for art-pass "Player look slots", "Player poses", "Swimmers at the water line" and
## "Clothing colours" (design.md C1, C2; task 5.8), run windowed (the shader and the sea need a real
## renderer, so never headless and never in CI):
##   godot --path game res://tests/manual/capture_looks.tscn -- [--out=<dir>]
## <dir> defaults to the repository's docs/art-pass/. It writes:
##   looks.png: composed with LookComposer and coloured as the shader colours the clothing, on sand,
##     in three rows: the four slot looks in their slot colours; slot 0's look in skin rows 0-2;
##     slot 0's body in hair_0 against hair_3. Each look stands facing down, right and up.
##   looks_crouch.png, looks_swim.png, looks_dive.png, looks_downed.png and looks_night.png: the four
##     slots as real player scenes on the real sandbar, in a SubViewport, enlarged ×3. Crouch on the
##     beach; swim and dive in the sea; downed (top row) above dead (bottom row) on the beach; night
##     standing on the beach and swimming beside it, under the day-night tint at night.
## The bodies never simulate (their processing is off); only their Look reads the states set here.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
const LAYOUT_PATH: String = "res://resources/islands/sandbar.tres"
const SAND: Color = Color8(0xd9, 0xa0, 0x66)
const CELL: int = 32
const PAD: int = 4
const LOOKS_ZOOM: int = 4
const VIEW_ZOOM: int = 3
const SETTLE_FRAMES: int = 30
## The standing frames of looks.png: idle down, side (right) and up, as (column, row) cells.
const STAND_CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
## The facing of each slot's body in the scene captures.
const FACINGS: Array[Facing.Dir] = [Facing.Dir.DOWN, Facing.Dir.RIGHT, Facing.Dir.UP, Facing.Dir.LEFT]
## Bodies stand this many cells apart; a capture spans this many cells around them.
const SPACING: int = 2
const MARGIN: Vector2i = Vector2i(2, 3)
## Night: a quarter of the way into the night phase, past the dusk blend.
const NIGHT_S: float = DayClock.NIGHT_START_S + 75.0
const LAND: Array[DataEnums.Terrain] = [DataEnums.Terrain.BEACH]
const SEA: Array[DataEnums.Terrain] = [DataEnums.Terrain.SHALLOWS, DataEnums.Terrain.DEEP]
## Night: the most rows between the beach row and the sea row below it.
const SHORE_MAX_STEP: int = 4

var _out_dir: String = ""
var _art: BodyArt = null
var _island: IslandLayout = null


func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/art-pass").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	WeatherManager.stop()
	_art = BodyArt.standard()
	_island = IslandLayout.build(load(LAYOUT_PATH) as IslandLayoutData)
	_save(_looks_sheet(), "looks")
	var land: Vector2i = _row_start(LAND, 1)
	var sea: Vector2i = _row_start(SEA, 1)
	await _capture("looks_crouch", land, 1, func(body: PlayerBody, _row: int) -> void:
		body.movement_state = MovementStep.Move.CROUCH)
	await _capture("looks_swim", sea, 1, func(body: PlayerBody, _row: int) -> void:
		body.movement_state = MovementStep.Move.SWIM)
	await _capture("looks_dive", sea, 1, func(body: PlayerBody, _row: int) -> void:
		body.movement_state = MovementStep.Move.DIVE
		body.stealth_state = MovementStep.Stealth.SUBMERGED)
	await _capture("looks_downed", _row_start(LAND, 2), 2, func(body: PlayerBody, row: int) -> void:
		if row == 0:
			body.downed = true
		else:
			body.meters.dead = true)
	WeatherManager.sky.start_at(NIGHT_S)
	var stand_then_swim := func(body: PlayerBody, row: int) -> void:
		if row == 1:
			body.movement_state = MovementStep.Move.SWIM
	var shore: Array[Vector2i] = _shore_start()
	await _capture("looks_night", shore[0], 2, stand_then_swim, true, shore[1].x)
	LookComposer.clear_cache()
	get_tree().quit()


# looks.png: the slot looks, the skin rows and the two hairs, each standing in three facings.
func _looks_sheet() -> Image:
	var ramps: Image = ArtTuning.standard().player_ramps.get_image()
	var base: PlayerLookData = _art.look_for_slot(0)
	var rows: Array[Array] = [[], [], []]
	for slot: int in 4:
		rows[0].append([_art.look_for_slot(slot), slot])
	for skin_row: int in 3:
		var look := base.duplicate() as PlayerLookData
		look.id = StringName("%s_skin_%d" % [base.id, skin_row])
		look.skin_row = skin_row
		rows[1].append([look, 0])
	for hair: StringName in [&"hair_0", &"hair_3"]:
		var look := base.duplicate() as PlayerLookData
		look.id = StringName("%s_%s" % [base.id, hair])
		look.hair_id = hair
		rows[2].append([look, 0])
	var look_w: int = STAND_CELLS.size() * CELL + PAD
	var sheet := Image.create_empty(4 * look_w + PAD, rows.size() * (CELL + PAD) + PAD, false, Image.FORMAT_RGBA8)
	sheet.fill(SAND)
	for row: int in rows.size():
		for i: int in rows[row].size():
			var look: PlayerLookData = rows[row][i][0]
			var composed: ComposedLook = LookComposer.compose(look)
			if not composed.fallbacks.is_empty():
				push_warning("capture_looks: %s fell back for %s" % [look.id, composed.fallbacks])
			# Row 0 of player_ramps.png is the key ramp; slot n is row n + 1, as the shader swaps it.
			var drawn: Image = PaletteSwap.swap_rows(composed.image, ramps, PaletteSwap.KEY_ROW, rows[row][i][1] + 1)
			for f: int in STAND_CELLS.size():
				var at := Vector2i(PAD + i * look_w + f * CELL, PAD + row * (CELL + PAD))
				sheet.blend_rect(drawn, Rect2i(STAND_CELLS[f] * CELL, Vector2i(CELL, CELL)), at)
	sheet.resize(sheet.get_width() * LOOKS_ZOOM, sheet.get_height() * LOOKS_ZOOM, Image.INTERPOLATE_NEAREST)
	return sheet


# One scene capture: the island, `rows` rows of the four slots from `start`, each body set by
# `setup(body, row)`, and a CanvasModulate at the sky's tint when `night`.
func _capture(capture: String, start: Vector2i, rows: int, setup: Callable, night: bool = false, row_step: int = 1) -> void:
	var cells := Rect2i(start - MARGIN, Vector2i(3 * SPACING + 1, (rows - 1) * row_step + 1) + MARGIN * 2)
	var view := SubViewport.new()
	view.size = cells.size * IslandLayout.TILE
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = load(LAYOUT_PATH) as IslandLayoutData
	island.with_creatures = false
	island.position = -Vector2(cells.position * IslandLayout.TILE)
	view.add_child(island)
	if night:
		view.add_child(TINT_SCENE.instantiate())
	for row: int in rows:
		for slot: int in 4:
			var body := PLAYER_SCENE.instantiate() as PlayerBody
			body.process_mode = Node.PROCESS_MODE_DISABLED
			body.look_slot = slot
			body.local_player = false
			var cell := start + Vector2i(slot * SPACING, row * row_step)
			body.position = island.position + IslandLayout.cell_center(cell)
			view.add_child(body)
			# Its _ready may make the camera current, which would centre the view on it.
			body.camera.enabled = false
			setup.call(body, row)
			var look := body.get_node(^"Look") as PlayerLook
			look.process_mode = Node.PROCESS_MODE_ALWAYS
			look.facing.dir = FACINGS[slot]
			if FACINGS[slot] == Facing.Dir.LEFT or FACINGS[slot] == Facing.Dir.RIGHT:
				look.facing.last_side = FACINGS[slot]
	await _frames(SETTLE_FRAMES)
	var image := view.get_texture().get_image()
	image.resize(image.get_width() * VIEW_ZOOM, image.get_height() * VIEW_ZOOM, Image.INTERPOLATE_NEAREST)
	_save(image, capture)
	view.queue_free()
	await _frames(2)


# The first cell, nearest the solo spawn, from which `rows` rows of four cells SPACING apart all
# lie on `kinds`.
func _row_start(kinds: Array[DataEnums.Terrain], rows: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	for y: int in _island.size.y:
		for x: int in _island.size.x:
			var cell := Vector2i(x, y)
			if _fits(cell, kinds, rows) and (best.x < 0 or _nearer(cell, best)):
				best = cell
	if best.x < 0:
		push_error("capture_looks: no %d row(s) of four %s cells on the sandbar" % [rows, kinds])
		return _island.solo_spawn
	return best


# Night: a beach row with a sea row `step` rows below it (the smallest step there is, then the
# nearest the spawn), so standing and swimming show together. Returns (cell, step).
func _shore_start() -> Array[Vector2i]:
	for step: int in range(1, SHORE_MAX_STEP + 1):
		var best := Vector2i(-1, -1)
		for y: int in _island.size.y - step:
			for x: int in _island.size.x:
				var cell := Vector2i(x, y)
				if _fits(cell, LAND, 1) and _fits(cell + Vector2i(0, step), SEA, 1) and (best.x < 0 or _nearer(cell, best)):
					best = cell
		if best.x >= 0:
			return [best, Vector2i(step, 0)]
	push_error("capture_looks: no beach row above a sea row on the sandbar")
	return [_row_start(LAND, 2), Vector2i(1, 0)]


func _fits(start: Vector2i, kinds: Array[DataEnums.Terrain], rows: int) -> bool:
	for row: int in rows:
		for i: int in 4:
			var cell := start + Vector2i(i * SPACING, row)
			if cell.x >= _island.size.x or cell.y >= _island.size.y:
				return false
			if not kinds.has(_island.terrain.terrain_at(cell)):
				return false
	return true


func _nearer(cell: Vector2i, than: Vector2i) -> bool:
	var spawn := _island.solo_spawn
	return (cell - spawn).length_squared() < (than - spawn).length_squared()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(image: Image, capture: String) -> void:
	var path := _out_dir.path_join(capture + ".png")
	print("capture_looks: %s (%s)" % [path, error_string(image.save_png(path))])
