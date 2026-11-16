class_name CrossingHud
extends CanvasLayer
## The crossing's own HUD (crossing "Crossing HUD and telegraphs"; design.md D11): top-centre under
## the day phase and clear of the sign note's place (200, 22)–(440, 60), a strip from the departure
## island to the next with the vessel at the elapsed share and the vessel's integrity, and under it
## the short warning lines: the squall 30 s and 10 s before its hit, a fin as it shows, a leak as it
## opens. Built from the theme's HudPanel and HudStyle's colours, no new ones. It only reads its
## parent crossing, every frame, so every peer draws what it has; only that crossing's riders see it.

const LAYER: int = 3
const STRIP_RECT: Rect2 = Rect2(220.0, 68.0, 200.0, 12.0)
const LINE_RECT: Rect2 = Rect2(160.0, 81.0, 320.0, 10.0)
## The strip's track inside the panel, after the integrity text.
const TRACK_LEFT_PX: float = 96.0
const TRACK_RIGHT_PX: float = 6.0
const MARK_SIZE: Vector2 = Vector2(3.0, 4.0)

## The peer whose view this is; the session's own by default (tests set it).
var local_peer: int = 0
var text: CrossingText = CrossingText.standard()

var _panel: PanelContainer
var _label: Label
var _track: Control
var _line: Label
var _known_leaks: int = 0
var _leak_line_until_s: float = -1.0


func _ready() -> void:
	layer = LAYER
	_panel = PanelContainer.new()
	_panel.name = "Strip"
	_panel.theme_type_variation = &"HudPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = STRIP_RECT.position
	_panel.size = STRIP_RECT.size
	add_child(_panel)
	_label = Label.new()
	_label.name = "Integrity"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_track = Control.new()
	_track.name = "Track"
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.position = STRIP_RECT.position
	_track.size = STRIP_RECT.size
	_track.draw.connect(_draw_track)
	add_child(_track)
	_line = Label.new()
	_line.name = "Line"
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.position = LINE_RECT.position
	_line.size = LINE_RECT.size
	add_child(_line)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


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
	_track.visible = shown
	_line.visible = shown
	if not shown:
		return
	var open: int = crossing.leaks.count_on(0) if not crossing.is_board_route() else crossing.leaks.count_on(_viewer())
	if open > _known_leaks:
		_leak_line_until_s = crossing.elapsed_s + text.line_s
	_known_leaks = open
	var locale: String = _locale()
	_label.text = integrity_text(locale)
	_line.text = current_line(locale)
	_track.queue_redraw()


func _draw_track() -> void:
	var left: float = TRACK_LEFT_PX
	var right: float = STRIP_RECT.size.x - TRACK_RIGHT_PX
	var middle: float = STRIP_RECT.size.y * 0.5
	_track.draw_line(Vector2(left, middle), Vector2(right, middle), HudStyle.TRACK, 1.0)
	_track.draw_line(Vector2(left, middle), Vector2(lerpf(left, right, progress()), middle), HudStyle.CREAM, 1.0)
	var mark_x: float = roundf(lerpf(left, right, progress()) - MARK_SIZE.x * 0.5)
	_track.draw_rect(Rect2(Vector2(mark_x, middle - MARK_SIZE.y * 0.5), MARK_SIZE).grow(1.0), HudStyle.OUTLINE)
	_track.draw_rect(Rect2(Vector2(mark_x, middle - MARK_SIZE.y * 0.5), MARK_SIZE), HudStyle.SUN)


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
