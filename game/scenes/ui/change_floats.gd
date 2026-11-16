class_name ChangeFloats
extends Control
## survival-meters "Change floats over the body" (damage-feedback design D9, D13): over every player
## of the run, on every peer, a meter that moves at once floats its signed change ("+15 Sed") in
## that meter's colour, and a status that clears floats "Sin sangrado". The changes are sorted from
## the meters and statuses this peer already holds for each body (MeterWatch, StatusWatch), so a
## teammate's coconut floats too, and nothing is sent. A health hit and every drain float nothing
## (owner, Q3). Each float starts just above the head, or above the name tag while it shows, rises
## float_rise_px over float_s while fading, and a newer float pushes the ones still showing over
## that body up by float_stack_px (SPD's FloatingText.push). Drawn in the HUD layer like the hidden
## mark, so the night tint and the Suave filter leave it alone; nothing shows while a screen is over
## the run. Drawing only.

## Space between a float's bottom edge and the head or the name tag.
const HEAD_GAP_PX: float = 3.0
const FONT_SIZE: int = 8
const OUTLINE_PX: int = 2
const TAG_NAME: StringName = &"NameTag"

## The run's session (its players), or null.
var session: CoopSession = null
## Maps a point of the world's canvas into the HUD (RunHud.world_to_hud).
var to_hud: Callable = func(point: Vector2) -> Vector2: return point
## Nothing shows while a screen is over the run.
var screen_shown: bool = false:
	set(value):
		screen_shown = value
		visible = not value
var locale: String = "es"

var _tuning: HurtCueTuning = HurtCues.tuning()
var _text: HudText = HudText.load_default()
# Per body (by instance id): its watches and its floats.
var _bodies: Dictionary[int, _Followed] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	step(delta)


## Follows the players of `run_session` from now on, forgetting any before.
func bind(run_session: CoopSession) -> void:
	session = run_session
	for followed: _Followed in _bodies.values():
		followed.free_floats()
	_bodies.clear()


## One frame: every body's changes are sorted, new floats made, every float moved on.
func step(delta: float) -> void:
	var seen: Dictionary[int, bool] = {}
	if is_instance_valid(session):
		for peer_id: int in session.peer_ids():
			var player := session.body(peer_id)
			if not is_instance_valid(player) or not player.is_inside_tree():
				continue
			var key: int = player.get_instance_id()
			seen[key] = true
			var followed: _Followed = _bodies.get(key)
			if followed == null:
				followed = _Followed.new(player, _tuning)
				_bodies[key] = followed
			_sort(followed, delta)
	for key: int in _bodies.keys():
		if not seen.has(key):
			_bodies[key].free_floats()
			_bodies.erase(key)
	for followed: _Followed in _bodies.values():
		_move(followed, delta)


## The texts floating over `player` now, oldest first.
func texts_over(player: PlayerBody) -> PackedStringArray:
	var texts := PackedStringArray()
	var followed: _Followed = _bodies.get(player.get_instance_id()) if is_instance_valid(player) else null
	if followed != null:
		for label: Label in followed.labels:
			texts.append(label.text)
	return texts


## The colour of the float reading `text` over `player`, or transparent.
func color_of(player: PlayerBody, text: String) -> Color:
	var label := _label(player, text)
	return label.get_theme_color(&"font_color") if label != null else Color.TRANSPARENT


## Where the float reading `text` over `player` sits, in HUD pixels, or an empty rect.
func rect_of(player: PlayerBody, text: String) -> Rect2:
	var label := _label(player, text)
	return label.get_rect() if label != null else Rect2()


## How many floats are drawn now.
func shown_count() -> int:
	if not is_visible_in_tree():
		return 0
	var count: int = 0
	for followed: _Followed in _bodies.values():
		count += followed.labels.size()
	return count


func _label(player: PlayerBody, text: String) -> Label:
	var followed: _Followed = _bodies.get(player.get_instance_id()) if is_instance_valid(player) else null
	if followed == null:
		return null
	for label: Label in followed.labels:
		if label.text == text:
			return label
	return null


# Sorts this frame's changes on one body into new floats.
func _sort(followed: _Followed, delta: float) -> void:
	var player: PlayerBody = followed.player
	var meters: SurvivalMeters = player.meters
	var gone: bool = player.left_island
	for meter: int in followed.watches:
		var watch: MeterWatch = followed.watches[meter]
		var change: MeterWatch.Change = watch.observe(meters.value(meter as DataEnums.Meter), meters.dead or gone, delta)
		if change == MeterWatch.Change.JUMP or (change == MeterWatch.Change.HIT and meter != DataEnums.Meter.HEALTH):
			var amount: int = roundi(watch.last_change)
			if amount != 0:
				_add(followed, "%+d %s" % [amount, _text.meter_word(meter as DataEnums.Meter, locale)], _tuning.meter_colors.get(meter, Color.WHITE))
	var cured: int = followed.statuses.observe(meters.status_flags, meters.dead or gone)
	for status: DataEnums.Status in StatusWatch.statuses(cured):
		_add(followed, _text.line(&"cured", locale) % _text.status_word(status, locale), _tuning.cure_color)


func _add(followed: _Followed, text: String, color: Color) -> void:
	for older: _Float in followed.floats:
		older.lift_px += _tuning.float_stack_px
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", HudStyle.OUTLINE)
	label.add_theme_constant_override(&"outline_size", OUTLINE_PX)
	add_child(label)
	label.size = label.get_minimum_size()
	followed.floats.append(_Float.new(label))
	followed.labels.append(label)


# Ages, rises, fades and places the floats over one body; drops the ones whose time is up.
func _move(followed: _Followed, delta: float) -> void:
	var kept: Array[_Float] = []
	for item: _Float in followed.floats:
		item.age_s += delta
		if item.age_s >= _tuning.float_s:
			item.label.queue_free()
			followed.labels.erase(item.label)
			continue
		kept.append(item)
	followed.floats = kept
	if followed.floats.is_empty() or not is_instance_valid(followed.player):
		return
	var canvas: Transform2D = followed.player.get_global_transform_with_canvas()
	var anchor: Vector2 = to_hud.call(canvas.origin)
	var top: Vector2 = to_hud.call(canvas * Vector2(0.0, _top_of(followed.player)))
	for item: _Float in followed.floats:
		var t: float = clampf(item.age_s / _tuning.float_s, 0.0, 1.0)
		var bottom: float = roundf(top.y) - HEAD_GAP_PX - item.lift_px - roundf(_tuning.float_rise_px * t)
		var label_size: Vector2 = item.label.size
		item.label.position = Vector2(roundf(anchor.x - label_size.x / 2.0), bottom - label_size.y)
		item.label.modulate.a = 1.0 - t * t


# The topmost drawn point over the body's origin, in its own pixels: the name tag's label while it
# shows, else the head (as BodyMarks places the hidden mark).
func _top_of(player: PlayerBody) -> float:
	var look := player.get_node_or_null(^"BodyLook") as BodyLook
	var top: float = look.head_y() if look != null else 0.0
	var tag := player.get_node_or_null(NodePath(TAG_NAME)) as NameTag
	if tag != null and tag.visible and tag.label != null:
		top = minf(top, tag.position.y + tag.label.position.y)
	return top


# One body followed: a watch per meter, a status watch and its floats.
class _Followed:
	extends RefCounted

	var player: PlayerBody
	var watches: Dictionary[int, MeterWatch] = {}
	var statuses: StatusWatch = StatusWatch.new()
	var floats: Array[_Float] = []
	var labels: Array[Label] = []

	func _init(body: PlayerBody, tuning: HurtCueTuning) -> void:
		player = body
		for meter: int in DataEnums.Meter.values():
			if meter != DataEnums.Meter.NONE:
				watches[meter] = MeterWatch.new(tuning.change_margin, tuning.steady_forget_s)

	func free_floats() -> void:
		for label: Label in labels:
			if is_instance_valid(label):
				label.queue_free()
		labels.clear()
		floats.clear()


# One float: its label, its age and how far newer ones pushed it up.
class _Float:
	extends RefCounted

	var label: Label
	var age_s: float = 0.0
	var lift_px: float = 0.0

	func _init(made: Label) -> void:
		label = made
