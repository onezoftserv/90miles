class_name CrossingHud
extends CanvasLayer
## The crossing's own HUD (crossing "Crossing HUD and telegraphs"; design.md D11): top-centre under
## the day phase and clear of the sign note's place (200, 22)–(440, 60), a strip from the departure
## island to the next with the vessel at the elapsed share and the vessel's integrity, and under it
## the short warning lines: the squall 30 s and 10 s before its hit, a fin as it shows, a leak as it
## opens. In the HUD window kit (hud-window-kit D14): the strip is a `HudPanel` window, the line a
## `HudPanelThin` 10 px row shown only while it says something, both in RunHud's outside-panel group
## so the interact prompt keeps clear of them. The track is a bar box like the meters': a 1 px
## outline round the deep-sea steps, the travelled part lighter, the vessel marker in the sun yellow;
## the integrity reads cream, orange at half and alert red at a quarter, the meter labels' steps.
## It only reads its parent crossing, every frame, so every peer draws what it has; only that
## crossing's riders see it.

const LAYER: int = 3
## Each window is an empty panel with its text laid over it on the same rect, as the kit's own thin
## rows are (hud_notice.tscn), so the panel keeps its size.
const STRIP_RECT: Rect2 = Rect2(220.0, 68.0, 200.0, 12.0)
const LINE_RECT: Rect2 = Rect2(160.0, 81.0, 320.0, 10.0)
## The integrity text's inset from the strip's left edge.
const LABEL_INSET_PX: float = 4.0
## The strip's track inside the panel starts after the integrity text (8 px glyphs) and this gap,
## and keeps at least TRACK_MIN_PX of length; it ends this far from the strip's right edge.
const TRACK_GAP_PX: float = 4.0
const TRACK_MIN_PX: float = 40.0
const TRACK_RIGHT_PX: float = 6.0
const MARK_SIZE: Vector2 = Vector2(2.0, 6.0)
## The bar box's track, 4 px tall inside its outline: the master palette's deep sea dark (still to
## go) and deep sea light (gone by) (hud-window-kit D14).
const TRACK_HEIGHT_PX: float = 4.0
const TRACK_AHEAD: Color = Color("#2a5578")
const TRACK_DONE: Color = Color("#3a6f92")
## The integrity steps to orange at this share of the vessel's maximum and to alert red at the next.
const WARN_SHARE: float = 0.5
const ALERT_SHARE: float = 0.25

## The peer whose view this is; the session's own by default (tests set it).
var local_peer: int = 0
var text: CrossingText = CrossingText.standard()

var _panel: PanelContainer
var _label: Label
var _track: Control
var _line_panel: PanelContainer
var _line: Label
var _track_left_px: float = 60.0
var _known_leaks: int = 0
var _leak_line_until_s: float = -1.0


func _ready() -> void:
	layer = LAYER
	_panel = PanelContainer.new()
	_panel.name = "Strip"
	_panel.theme_type_variation = &"HudPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_to_group(RunHud.OUTSIDE_PANEL_GROUP)
	add_child(_panel)
	_place(_panel, STRIP_RECT)
	_label = Label.new()
	_label.name = "Integrity"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = true
	add_child(_label)
	_place(_label, Rect2(STRIP_RECT.position + Vector2(LABEL_INSET_PX, 0.0), Vector2(_track_left_px - LABEL_INSET_PX, STRIP_RECT.size.y)))
	_track = Control.new()
	_track.name = "Track"
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.position = STRIP_RECT.position
	_track.size = STRIP_RECT.size
	_track.draw.connect(_draw_track)
	add_child(_track)
	_line_panel = PanelContainer.new()
	_line_panel.name = "LinePanel"
	_line_panel.theme_type_variation = &"HudPanelThin"
	_line_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_panel.add_to_group(RunHud.OUTSIDE_PANEL_GROUP)
	add_child(_line_panel)
	_place(_line_panel, LINE_RECT)
	_line = Label.new()
	_line.name = "Line"
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.clip_text = true
	add_child(_line)
	_place(_line, LINE_RECT)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


# A window keeps `rect` once in the tree (sizing it before it enters lets the theme's default take
# over).
func _place(window: Control, rect: Rect2) -> void:
	window.position = rect.position
	window.size = rect.size


## The share of the crossing gone by, 0 to 1.
func progress() -> float:
	var crossing := get_parent() as Crossing
	if crossing == null or crossing.plan == null or crossing.plan.length_s <= 0.0:
		return 0.0
	return clampf(crossing.elapsed_s / crossing.plan.length_s, 0.0, 1.0)


## The strip's words for the viewer: the vessel's name and its integrity out of its maximum, or
## "A nado" with none.
func integrity_text(locale: String = "es") -> String:
	var crossing := get_parent() as Crossing
	if crossing == null or crossing.route == null:
		return ""
	var vessel := crossing.vessel_of(_viewer())
	if not vessel.intact():
		return HudText.pick(text.swimming, locale)
	var name_pair: PackedStringArray = text.vessel_names.get(int(crossing.route.vessel), text.vessel_names.get(0, PackedStringArray()))
	return "%s %d/%d" % [HudText.pick(name_pair, locale), ceili(vessel.value), roundi(vessel.maximum)]


## The integrity's colour for the viewer's vessel: cream, orange at half its maximum or less, alert
## red at a quarter or less (and for a sunk vessel).
func integrity_color() -> Color:
	var crossing := get_parent() as Crossing
	if crossing == null:
		return HudStyle.CREAM
	var vessel := crossing.vessel_of(_viewer())
	if not vessel.has_integrity():
		return HudStyle.CREAM
	var share: float = vessel.value / vessel.maximum if vessel.maximum > 0.0 else 0.0
	if not vessel.intact() or share <= ALERT_SHARE:
		return HudStyle.ALERT
	if share <= WARN_SHARE:
		return HudStyle.ORANGE
	return HudStyle.CREAM


## The warning line showing now, or "" (the squall's two lines, a fin as it shows, a leak as it
## opens), each for `line_s`.
func current_line(locale: String = "es") -> String:
	var crossing := get_parent() as Crossing
	if crossing == null or crossing.plan == null:
		return ""
	var now: float = crossing.elapsed_s
	if now < _leak_line_until_s:
		return HudText.pick(text.leak, locale)
	for item: RefCounted in crossing.plan.events:
		var beat := item as CrossingBeat
		match beat.kind:
			CrossingBeat.Kind.SQUALL:
				if _showing(now, beat.time_s - text.squall_near_s):
					return HudText.pick(text.squall_near, locale)
				if _showing(now, beat.time_s - text.squall_far_s):
					return HudText.pick(text.squall_far, locale)
			CrossingBeat.Kind.SHARK_PASS:
				var warn_at: float = maxf(beat.time_s - crossing.tuning.shark_lead_s, 0.0)
				if _showing(now, warn_at) and not crossing.is_shooed(beat):
					return HudText.pick(text.fin_east if beat.side() == CrossingBeat.Side.EAST else text.fin_west, locale)
	return ""


func _showing(now: float, from_s: float) -> bool:
	return from_s >= 0.0 and now >= from_s - 0.0001 and now < from_s + text.line_s


func _refresh() -> void:
	var crossing := get_parent() as Crossing
	var shown: bool = crossing != null and crossing.plan != null and not crossing.finished and crossing.peers().has(_viewer())
	_panel.visible = shown
	_label.visible = shown
	_track.visible = shown
	if not shown:
		_line_panel.visible = false
		_line.visible = false
		return
	var open: int = crossing.leaks.count_on(0) if not crossing.is_board_route() else crossing.leaks.count_on(_viewer())
	if open > _known_leaks:
		_leak_line_until_s = crossing.elapsed_s + text.line_s
	_known_leaks = open
	var locale: String = _locale()
	_label.text = integrity_text(locale)
	_track_left_px = minf(LABEL_INSET_PX + HudStyle.GLYPH_PX * _label.text.length() + TRACK_GAP_PX, STRIP_RECT.size.x - TRACK_RIGHT_PX - TRACK_MIN_PX)
	_label.size.x = _track_left_px - LABEL_INSET_PX
	_label.add_theme_color_override(&"font_color", integrity_color())
	_line.text = current_line(locale)
	_line_panel.visible = not _line.text.is_empty()
	_line.visible = _line_panel.visible
	_track.queue_redraw()


## The bar box's track rect inside the strip, in the strip's own coordinates (outline outside it).
func track_rect() -> Rect2:
	var top: float = roundf((STRIP_RECT.size.y - TRACK_HEIGHT_PX) * 0.5)
	return Rect2(_track_left_px, top, STRIP_RECT.size.x - TRACK_RIGHT_PX - _track_left_px, TRACK_HEIGHT_PX)


func _draw_track() -> void:
	var track := track_rect()
	_track.draw_rect(track.grow(1.0), HudStyle.OUTLINE)
	_track.draw_rect(track, TRACK_AHEAD)
	var done_px: float = roundf(track.size.x * progress())
	_track.draw_rect(Rect2(track.position, Vector2(done_px, track.size.y)), TRACK_DONE)
	var mark_x: float = clampf(track.position.x + done_px - MARK_SIZE.x * 0.5, track.position.x, track.end.x - MARK_SIZE.x)
	var mark := Rect2(Vector2(roundf(mark_x), track.get_center().y - MARK_SIZE.y * 0.5), MARK_SIZE)
	_track.draw_rect(mark.grow(1.0), HudStyle.OUTLINE)
	_track.draw_rect(mark, HudStyle.SUN)


func _viewer() -> int:
	if local_peer != 0:
		return local_peer
	var crossing := get_parent() as Crossing
	var session := crossing.session() if crossing != null else null
	return session.multiplayer.get_unique_id() if session != null else 1


func _locale() -> String:
	var crossing := get_parent() as Crossing
	var session := crossing.session() if crossing != null else null
	return session.locale if session != null else "es"
