class_name CrossingHazards
extends Node2D
## What comes down the crossing's lanes (crossing "Scrolling hazards", "Flotsam"; design.md D2, D11):
## rocks, debris and flotsam pieces, drawn where the plan, the elapsed time and the vessel's lateral
## position put them. Rocks and debris are placeholder shapes in the master palette, 1 px dark
## outline, until their art; a flotsam piece is drawn as loot (art-mood-pass D8): the item's own
## icon cut at its waterline, bobbing 1 px, with a dashed ring at the line, the plank its own board.
## It only reads its parent, every frame, so a client and a late joiner draw what they received;
## the crossing never names it. `Hazards` in crossing.tscn, at z −30: over the sea, under the deck.
## Open leaks are drawn by a child at z −19, just over the deck, as spurts of water (crossing "Leaks").

## Master palette (docs/ASSETS.md): rock body and top, wood, outline, foam.
const ROCK_COLOR: Color = Color("#595652")
const ROCK_TOP: Color = Color("#847e87")
const WOOD_COLOR: Color = Color("#8a6f30")
const WOOD_DARK: Color = Color("#663931")
const OUTLINE: Color = Color("#222034")
const FOAM: Color = Color(1.0, 1.0, 1.0, 0.75)
const NAIL: Color = Color("#9badb7")
const SPURT: Color = Color("#cbdbfc")
const SPURT_DARK: Color = Color("#639bff")
## Leak spurts sit just over the deck and under the riders.
const SPURT_Z: int = -19

var _spurts: Node2D
var _clock_s: float = 0.0

var _items: Dictionary[StringName, Texture2D] = {}
## art-mood-pass D8: each item icon's part above its waterline, cut once.
var _cuts: Dictionary[StringName, Rect2i] = {}

## art-mood-pass D8: the plank (16x5) and the ring round a floating piece (2 frames of 18x5).
@export var plank_texture: Texture2D
@export var ring_texture: Texture2D


func _init() -> void:
	add_to_group(&"art_view")


func _ready() -> void:
	_spurts = Node2D.new()
	_spurts.name = "Spurts"
	_spurts.z_as_relative = false
	_spurts.z_index = SPURT_Z
	_spurts.draw.connect(_draw_spurts)
	add_child(_spurts)


func _process(delta: float) -> void:
	_clock_s += delta
	queue_redraw()
	if _spurts != null:
		_spurts.queue_redraw()


## Where each open leak is drawn, in the crossing's coordinates.
func shown_leaks() -> Array[Vector2]:
	var crossing := get_parent() as Crossing
	var spots: Array[Vector2] = []
	if crossing == null or crossing.finished:
		return spots
	for leak: Dictionary in crossing.leaks.list:
		spots.append(crossing.leak_position(leak) - global_position)
	return spots


# A leak: a little fountain of water that bobs.
func _draw_spurts() -> void:
	var rise: float = 1.0 + roundf(sin(_clock_s * 9.0))
	for at: Vector2 in shown_leaks():
		var base := at.round()
		_spurts.draw_rect(Rect2(base + Vector2(-3, 1), Vector2(6, 2)), SPURT_DARK)
		_spurts.draw_rect(Rect2(base + Vector2(-1, -2 - rise), Vector2(2, 3 + rise)), SPURT)
		_spurts.draw_rect(Rect2(base + Vector2(-3, -1 - rise), Vector2(1, 1)), SPURT)
		_spurts.draw_rect(Rect2(base + Vector2(2, -1 - rise), Vector2(1, 1)), SPURT)


## The lane beats on the sea now, each as [beat, centre in the crossing's coordinates], for tests
## and the drawing alike.
func shown_beats() -> Array:
	var crossing := get_parent() as Crossing
	var shown: Array = []
	if crossing == null or crossing.plan == null or crossing.finished:
		return shown
	var sea := crossing.sea_rect()
	for item: RefCounted in crossing.plan.events:
		var beat := item as CrossingBeat
		if not beat.is_lane_beat() or not crossing.beat_shown(beat):
			continue
		var at: Vector2 = crossing.beat_center(beat)
		if sea.grow(Crossing.TILE_PX).has_point(at):
			shown.append([beat, at - global_position])
	return shown


func _draw() -> void:
	var crossing := get_parent() as Crossing
	if crossing == null:
		return
	for pair: Array in shown_beats():
		var beat := pair[0] as CrossingBeat
		var at: Vector2 = (pair[1] as Vector2).round()
		match beat.kind:
			CrossingBeat.Kind.ROCK:
				_draw_rock(at, crossing.beat_width_tiles(beat) * Crossing.TILE_PX)
			CrossingBeat.Kind.DEBRIS:
				_draw_debris(at)
			CrossingBeat.Kind.FLOTSAM:
				_draw_piece(beat)


func _draw_rock(at: Vector2, width_px: float) -> void:
	var half := Vector2(width_px * 0.5 - 1.0, 5.0)
	draw_rect(Rect2(at - half - Vector2(1, 1), half * 2.0 + Vector2(2, 2)), FOAM)
	var body := PackedVector2Array([
		at + Vector2(-half.x, 2), at + Vector2(-half.x + 3, -half.y), at + Vector2(half.x - 4, -half.y - 1),
		at + Vector2(half.x, 1), at + Vector2(half.x - 2, half.y), at + Vector2(-half.x + 2, half.y),
	])
	draw_colored_polygon(body, ROCK_COLOR)
	draw_rect(Rect2(at + Vector2(-half.x + 4, -half.y + 1), Vector2(width_px * 0.4, 2)), ROCK_TOP)
	body.append(body[0])
	draw_polyline(body, OUTLINE, 1.0)


func _draw_debris(at: Vector2) -> void:
	var rect := Rect2(at - Vector2(7, 2), Vector2(14, 5))
	draw_rect(rect.grow(1.0), FOAM)
	draw_rect(rect, WOOD_COLOR)
	draw_rect(Rect2(rect.position + Vector2(0, 3), Vector2(14, 2)), WOOD_DARK)
	draw_rect(Rect2(rect.position + Vector2(3, 1), Vector2(1, 1)), NAIL)
	draw_rect(Rect2(rect.position + Vector2(10, 1), Vector2(1, 1)), NAIL)
	draw_rect(rect, OUTLINE, false, 1.0)


## art-mood-pass D8: how flotsam beat `beat` is drawn now: {"texture", "region" (the part drawn),
## "at" (its texture's top left, bob included, in this node's coordinates), "bob" (0 or 1 px),
## "ring", "ring_at", "ring_frame"}. The piece stays centred on its beat, so the GRAB point, which
## follows the beat, stays on it. Empty when the beat has nothing to draw.
func piece_look(beat: CrossingBeat) -> Dictionary:
	var crossing := get_parent() as Crossing
	if crossing == null or crossing.plan == null:
		return {}
	var art := ArtTuning.standard()
	var id: StringName = crossing.tuning.flotsam_piece(beat.extra)
	var plank: bool = id == CrossingTuning.PLANK_ID
	var texture: Texture2D = plank_texture if plank else _texture(id)
	if texture == null:
		return {}
	var centre: Vector2 = (crossing.beat_center(beat) - global_position).round()
	var bob: int = CrossingArt.bob(crossing.plan.index_of(beat), crossing.elapsed_s, art)
	var size: Vector2 = texture.get_size()
	var region := Rect2(Vector2.ZERO, size) if plank else Rect2(_cut(id, texture))
	var at: Vector2 = (centre - size / 2.0).floor() + Vector2(0.0, bob)
	# The line: a cut icon's last drawn row, the plank's middle row.
	var line_y: float = at.y + (floorf(size.y / 2.0) if plank else region.end.y - 1.0)
	var ring_size := Vector2.ZERO
	if ring_texture != null:
		ring_size = Vector2(ring_texture.get_width() / 2.0, ring_texture.get_height())
	return {
		"texture": texture,
		"region": region,
		"at": at,
		"bob": bob,
		"ring": ring_texture,
		"ring_at": Vector2(centre.x - ring_size.x / 2.0, line_y - floorf(ring_size.y / 2.0)).floor(),
		"ring_frame": posmod(floori(crossing.elapsed_s / art.flotsam_bob_s), 2),
	}


func _draw_piece(beat: CrossingBeat) -> void:
	var look := piece_look(beat)
	if look.is_empty():
		return
	var region: Rect2 = look["region"]
	draw_texture_rect_region(look["texture"], Rect2(look["at"], region.size), region)
	var ring := look["ring"] as Texture2D
	if ring != null:
		var frame := Vector2(ring.get_width() / 2.0, ring.get_height())
		draw_texture_rect_region(ring, Rect2(look["ring_at"], frame), Rect2(Vector2(int(look["ring_frame"]) * frame.x, 0.0), frame))


func _cut(id: StringName, texture: Texture2D) -> Rect2i:
	if not _cuts.has(id):
		_cuts[id] = CrossingArt.waterline_cut(texture.get_image(), ArtTuning.standard())
	return _cuts[id]


func _texture(id: StringName) -> Texture2D:
	if not _items.has(id):
		var item := GameState.content.get_entry(&"items", id) as ItemData
		_items[id] = item.sprite if item != null else null
	return _items[id]
