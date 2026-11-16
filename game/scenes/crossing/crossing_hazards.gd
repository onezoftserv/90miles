class_name CrossingHazards
extends Node2D
## What comes down the crossing's lanes (crossing "Scrolling hazards", "Flotsam"; design.md D2, D11):
## rocks, debris and flotsam pieces, drawn where the plan, the elapsed time and the vessel's lateral
## position put them. Placeholder shapes in the master palette, 1 px dark outline, until their art.
## It only reads its parent, every frame, so a client and a late joiner draw what they received;
## the crossing never names it. `Hazards` in crossing.tscn, at z −30: over the sea, under the deck.

## Master palette (docs/ASSETS.md): rock body and top, wood, outline, foam.
const ROCK_COLOR: Color = Color("#595652")
const ROCK_TOP: Color = Color("#847e87")
const WOOD_COLOR: Color = Color("#8a6f30")
const WOOD_DARK: Color = Color("#663931")
const OUTLINE: Color = Color("#222034")
const FOAM: Color = Color(1.0, 1.0, 1.0, 0.75)
const NAIL: Color = Color("#9badb7")

var _items: Dictionary[StringName, Texture2D] = {}


func _init() -> void:
	add_to_group(&"art_view")


func _process(_delta: float) -> void:
	queue_redraw()


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
				_draw_piece(at, crossing.tuning.flotsam_piece(beat.extra))


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


func _draw_piece(at: Vector2, id: StringName) -> void:
	draw_circle(at + Vector2(0, 3), 5.0, FOAM)
	if id == CrossingTuning.PLANK_ID:
		var rect := Rect2(at - Vector2(8, 2), Vector2(16, 4))
		draw_rect(rect, WOOD_COLOR)
		draw_rect(rect, OUTLINE, false, 1.0)
		return
	var texture := _texture(id)
	if texture != null:
		draw_texture(texture, at - texture.get_size() * 0.5)


func _texture(id: StringName) -> Texture2D:
	if not _items.has(id):
		var item := GameState.content.get_entry(&"items", id) as ItemData
		_items[id] = item.sprite if item != null else null
	return _items[id]
