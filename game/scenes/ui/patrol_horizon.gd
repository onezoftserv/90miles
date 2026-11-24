class_name PatrolHorizon
extends Control
## guardacostas-stealth "Patrol cues" (design.md decision 11), drawn as art-guardacostas D8 makes it: the
## patrol boat's warning on the HUD's horizon band, the strip along the top where the squall line sits.
## While any patrol boat of the run is in HORIZON (the 20 s before its lap) a 9×7 boat chip from the HUD
## kit shows on the band: a lit hull at night, a grey hull by day (the phases are the boat's own
## `searchlight_phases`, read against THIS peer's day phase). It blinks: its colours for 0.3 s, then its
## outline alone for 0.2 s, and in the last 5 s of the warning twice as fast (0.15 s and 0.1 s), timed by
## the boat's synced clock (`route_t`) so every peer blinks together. It is placed along the band by the
## bearing of the boat's lap-start point from the viewing player (the camera follows them): straight up is
## the band's middle, east its right edge and west its left, and a point behind the viewer is clamped to
## the nearer edge; then it slides along the band to the nearer side clear of the top HUD windows on show
## (`avoid`). Drawn in the HUD layer so the night tint leaves its colours alone, and nothing is drawn
## while a screen is over the run. It has no text. It reads the boats' synced state and never writes
## anything, so it is the same on every peer.

const BAND_WIDTH: float = 640.0
const BAND_HEIGHT: float = 6.0
## The chip's size, its outline included.
const CHIP_SIZE: Vector2 = Vector2(9.0, 7.0)
## Rows from the band's top to the chip's top.
const MARK_TOP_PX: float = 1.0
## The blink: the chip's colours for BLINK_ON_S, then its outline alone for BLINK_OFF_S (2 Hz); in the
## last FAST_S seconds of the warning, FAST_ON_S and FAST_OFF_S (4 Hz).
const BLINK_ON_S: float = 0.3
const BLINK_OFF_S: float = 0.2
const FAST_S: float = 5.0
const FAST_ON_S: float = 0.15
const FAST_OFF_S: float = 0.1
const BEAT_EPSILON_S: float = 0.0001
## The kit's chips, named by the theme (`HudHorizon/icons/...`) so the art rules find them in use.
const ICON_TYPE: StringName = &"HudHorizon"
const DAY_ICON: StringName = &"boat_chip_day"
const NIGHT_ICON: StringName = &"boat_chip_night"
const OUTLINE_ICON: StringName = &"boat_chip_outline"
## What sits under a mark so it reads on a bright sea: the band's dark.
const UNDERLAY_COLOR: Color = HorizonLine.BAND_COLOR
## The bearing, in degrees from straight up, that reaches the band's edge.
const EDGE_BEARING_DEG: float = 90.0

## The run's session (its boats and its viewing player), or null.
var session: CoopSession = null
## The peer whose view this is.
var local_peer: int = CoopSession.HOST_ID
## Nothing is drawn while a screen is shown over the run.
var screen_shown: bool = false
## This peer's day phase; tests replace it.
var phase_source: Callable = func() -> DataEnums.DayPhase: return WeatherManager.phase()
## The top HUD windows on show, in HUD pixels, which a chip slides clear of.
var avoid: Callable = func() -> Array[Rect2]: return []
# Each mark on show: its rect in HUD pixels, whether it is the day's hull and whether it shows its colours.
var _rects: Array[Rect2] = []
var _hulls: Array[bool] = []
var _lit: Array[bool] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	position = Vector2.ZERO
	size = Vector2(BAND_WIDTH, BAND_HEIGHT)


func _process(_delta: float) -> void:
	tick()


## Follows the boats of `run_session` from now on, seen from `peer_id`'s player.
func bind(run_session: CoopSession, peer_id: int) -> void:
	session = run_session
	local_peer = peer_id
	tick()


## Places the marks for this frame.
func tick() -> void:
	_rects.clear()
	_hulls.clear()
	_lit.clear()
	if not screen_shown and is_instance_valid(session):
		var windows: Array[Rect2] = []
		windows.assign(avoid.call())
		var phase: DataEnums.DayPhase = phase_source.call()
		var viewer: PlayerBody = session.body(local_peer)
		var eye: Vector2 = viewer.global_position if viewer != null else Vector2.ZERO
		for node: Node in session.entities.get_children():
			var boat := node as Creature
			if boat == null or boat.is_queued_for_deletion() or not boat.is_patrol():
				continue
			if boat.state_id != PatrolRoute.State.HORIZON:
				continue
			var view: PatrolView = boat.view()
			if not view.valid:
				continue
			var hull: bool = not boat.data.patrol.searchlight_phases.has(phase)
			_rects.append(_place(view.start_px() - eye, windows))
			_hulls.append(hull)
			_lit.append(chip_lit(boat.route_t, boat.data.patrol.horizon_warning_s))
	queue_redraw()


## How many marks show.
func mark_count() -> int:
	return _rects.size()


## Mark `index`'s rect in HUD pixels.
func mark_rect(index: int) -> Rect2:
	return _rects[index]


## True when mark `index` is the by-day grey hull, false for the night's lit hull.
func is_hull(index: int) -> bool:
	return _hulls[index]


## True when mark `index` shows its colours now, false while it shows its outline alone.
func is_lit(index: int) -> bool:
	return _lit[index]


## The texture mark `index` is drawn with now.
func chip_texture(index: int) -> Texture2D:
	var icon: StringName = OUTLINE_ICON
	if _lit[index]:
		icon = DAY_ICON if _hulls[index] else NIGHT_ICON
	return get_theme_icon(icon, ICON_TYPE)


## Whether a chip shows its colours for a boat `route_t` seconds into its `warning_s` warning: 0.3 s on
## and 0.2 s off, then 0.15 s on and 0.1 s off in the last FAST_S seconds.
static func chip_lit(route_t: float, warning_s: float) -> bool:
	# A clock summed from 0.1 s ticks drifts below a beat's edge: a tenth of a millisecond keeps it on time.
	var t: float = route_t + BEAT_EPSILON_S
	var fast_from: float = warning_s - FAST_S
	if t < fast_from:
		return fposmod(t, BLINK_ON_S + BLINK_OFF_S) < BLINK_ON_S
	return fposmod(t - fast_from, FAST_ON_S + FAST_OFF_S) < FAST_ON_S


## The chip's left edge after sliding from `left` along the band clear of `windows`, to the nearer side
## of each it overlaps (the far side when the near one leaves the band).
static func slide(left: float, windows: Array[Rect2]) -> float:
	for _pass: int in 3:
		var moved: bool = false
		for other: Rect2 in windows:
			var rect := Rect2(Vector2(left, MARK_TOP_PX), CHIP_SIZE)
			if not rect.intersects(other):
				continue
			var to_left: float = other.position.x - 1.0 - CHIP_SIZE.x
			var to_right: float = other.end.x + 1.0
			var nearer: float = to_left if absf(to_left - left) <= absf(to_right - left) else to_right
			if nearer < 0.0:
				nearer = to_right
			elif nearer + CHIP_SIZE.x > BAND_WIDTH:
				nearer = to_left
			left = nearer
			moved = true
		if not moved:
			break
	return left


## The band's x for a point `gap` pixels from the viewer: its bearing from straight up, clamped.
static func bearing_x(gap: Vector2) -> float:
	if gap == Vector2.ZERO:
		return BAND_WIDTH / 2.0
	var bearing: float = rad_to_deg(atan2(gap.x, -gap.y))
	var across: float = clampf(bearing / EDGE_BEARING_DEG, -1.0, 1.0)
	return BAND_WIDTH / 2.0 + across * BAND_WIDTH / 2.0


# The chip centred on the bearing's x at whole pixels, kept inside the band, then slid clear of the top
# windows.
func _place(gap: Vector2, windows: Array[Rect2]) -> Rect2:
	var left: float = clampf(roundf(bearing_x(gap) - CHIP_SIZE.x / 2.0), 0.0, BAND_WIDTH - CHIP_SIZE.x)
	left = slide(left, windows)
	return Rect2(Vector2(left, MARK_TOP_PX) + global_position, CHIP_SIZE)


func _draw() -> void:
	for i: int in _rects.size():
		var rect := Rect2(_rects[i].position - global_position, _rects[i].size)
		draw_rect(rect.grow_individual(1.0, 1.0, 1.0, 1.0), UNDERLAY_COLOR)
		var chip: Texture2D = chip_texture(i)
		if chip != null:
			draw_texture(chip, rect.position)
