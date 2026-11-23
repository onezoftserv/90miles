class_name RainOverlay
extends Node2D
## A squall's rain (art-mood-pass "Squall on screen", design D3): `squall.tres`'s vfx_scene, which
## WeatherVfx puts under the day-night tint, so the sky's tint multiplies it and a fire's light
## lights it with no code of its own. It draws at z 10, over the actors and under the name tags.
## - Streaks: every frame it covers the camera's visible rect with fx/rain.png's 64 px tile,
##   anchored to the screen and scrolled down and to the left on its own clock. The light stage
##   shows for ArtTuning.rain_light_s after the squall starts, then the heavy one.
## - Splashes: fx/splash.png's 3 frames, at most ArtTuning.rain_splashes at once (half of them in
##   the light stage), each in its own time slot on a world cell that TerrainArt.mix32 picks from
##   (slot, index, view), so there is no random roll. A splash keeps its cell for its whole slot.
## Its process mode is ALWAYS, so the rain keeps falling under solo pause. Drawing only: it reads
## the sky and never writes it.

const TILE_PX: int = 64
const CELL_PX: int = 16
const SPLASH_SIZE: Vector2i = Vector2i(5, 3)
const SPLASH_FRAMES: int = 3
## A slot is the splash's frames and then this many empty frames, so a cell rests between splashes.
const SPLASH_REST_FRAMES: int = 2

## fx/rain.png (the light and the heavy 64 px tile side by side) and fx/splash.png (3 frames of 5×3).
@export var rain: Texture2D
@export var splash: Texture2D
## How fast the streaks fall, in px per second on each axis (down and to the left).
@export var fall_px_s: float = 96.0
## The splashes' frame rate, at most 12 (design D3).
@export var splash_fps: float = 10.0

## Defaults to the game's one sky.
var sky: WorldSky
## The overlay's own clock, in seconds since it entered.
var time_s: float = 0.0

var _tuning: ArtTuning
var _view: Rect2 = Rect2()
## Per splash index: the slot it is in and the cell it holds for that slot.
var _splash_slot: Dictionary[int, int] = {}
var _splash_cell: Dictionary[int, Vector2i] = {}


func _init() -> void:
	add_to_group(&"art_view")
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	if sky == null:
		sky = WeatherManager.sky
	_tuning = ArtTuning.standard()
	_view = visible_rect()


func _process(delta: float) -> void:
	time_s += delta
	_view = visible_rect()
	queue_redraw()


## The rect the camera shows, in this node's own coordinates.
func visible_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2()
	return get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()


## 0 for the light stage, 1 for the heavy one: light for ArtTuning.rain_light_s after the squall
## starts.
func stage() -> int:
	return 1 if elapsed_s() >= _tuning.rain_light_s else 0


## Seconds since the weather started: the synced weather's own (its duration less what is left)
## when it has a duration, so a peer that joins late sees the same stage; otherwise the overlay's
## clock.
func elapsed_s() -> float:
	var cycle: WeatherCycle = sky.weather if sky != null else null
	if cycle != null and cycle.current != null and cycle.current.duration_s > 0.0:
		return maxf(cycle.current.duration_s - cycle.current_left_s, 0.0)
	return time_s


## How many splashes the current stage shows at once.
func splash_count() -> int:
	var most: int = maxi(_tuning.rain_splashes, 0)
	@warning_ignore("integer_division")
	return most if stage() == 1 else most / 2


## The world cell that splash `index` lands on in time slot `slot`, inside `view` (in cells): the
## same for the same inputs on every peer and every run, mixed by TerrainArt.mix32 with no random
## generator.
static func splash_cell(slot: int, index: int, view: Rect2i) -> Vector2i:
	if view.size.x <= 0 or view.size.y <= 0:
		return view.position
	var across: int = TerrainArt.mix32(slot * 0x9e3779b1 + index * 0x85ebca77 + 0x165667b1)
	var down: int = TerrainArt.mix32(across ^ 0x27d4eb2f)
	return view.position + Vector2i(across % view.size.x, down % view.size.y)


## Where splash `index` sits inside its cell, in px (the tick stays whole inside the cell).
static func splash_offset(slot: int, index: int) -> Vector2i:
	var mixed: int = TerrainArt.mix32(slot * 0x7feb352d + index * 0x846ca68b + 0x5bd1e995)
	return Vector2i(mixed % (CELL_PX - SPLASH_SIZE.x + 1), (mixed >> 8) % (CELL_PX - SPLASH_SIZE.y + 1))


## The view in whole cells: every cell the camera's rect touches.
static func view_cells(rect: Rect2) -> Rect2i:
	var start := Vector2i(floori(rect.position.x / CELL_PX), floori(rect.position.y / CELL_PX))
	var end := Vector2i(ceili(rect.end.x / CELL_PX), ceili(rect.end.y / CELL_PX))
	return Rect2i(start, end - start)


func _draw() -> void:
	if _tuning == null or rain == null or splash == null or _view.size.x <= 0.0 or _view.size.y <= 0.0:
		return
	_draw_streaks()
	_draw_splashes()


# The tile anchored to the screen's top-left pixel and moved (-d, +d), d growing with the clock.
func _draw_streaks() -> void:
	var source := Rect2(stage() * TILE_PX, 0, TILE_PX, TILE_PX)
	var fall: int = posmod(floori(time_s * fall_px_s), TILE_PX)
	var origin := Vector2(floorf(_view.position.x) - fall, floorf(_view.position.y) + fall - TILE_PX)
	var columns: int = ceili(_view.size.x / TILE_PX) + 1
	var rows: int = ceili(_view.size.y / TILE_PX) + 2
	for row: int in rows:
		for column: int in columns:
			var at := origin + Vector2(column * TILE_PX, row * TILE_PX)
			draw_texture_rect_region(rain, Rect2(at, Vector2(TILE_PX, TILE_PX)), source)


# Splash i runs slots of SPLASH_FRAMES + SPLASH_REST_FRAMES frames, shifted by i so they never all
# start together; it takes a new cell only when its slot changes.
func _draw_splashes() -> void:
	var frames_per_slot: int = SPLASH_FRAMES + SPLASH_REST_FRAMES
	var view: Rect2i = view_cells(_view)
	var count: int = splash_count()
	for index: int in count:
		@warning_ignore("integer_division")
		var frame_clock: int = floori(time_s * minf(splash_fps, 12.0)) + index * frames_per_slot / maxi(count, 1)
		var slot: int = floori(float(frame_clock) / frames_per_slot)
		var frame: int = frame_clock - slot * frames_per_slot
		if _splash_slot.get(index, -1) != slot:
			_splash_slot[index] = slot
			_splash_cell[index] = splash_cell(slot, index, view)
		if frame >= SPLASH_FRAMES:
			continue
		var at: Vector2i = _splash_cell[index] * CELL_PX + splash_offset(slot, index)
		var source := Rect2(frame * SPLASH_SIZE.x, 0, SPLASH_SIZE.x, SPLASH_SIZE.y)
		draw_texture_rect_region(splash, Rect2(Vector2(at), Vector2(SPLASH_SIZE)), source)
