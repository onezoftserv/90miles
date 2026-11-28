class_name CrossingWake
extends Node2D
## art-mood-pass D7 ("A wake at the bow and the stern"): a ripple along the north edge of each drawn
## deck or board and a V of dashes trailing south from its stern, in #cbdbfc and #9badb7. The raft
## and the car get one wake, each afloat board a small one (the V's top middle), a sunk deck and a
## swim none; the frames step with the scroll. It stays inside the deck's x span, so it never meets
## the fin a tile off the side. CrossingArt.wakes says where. `Wake` in crossing.tscn, at z -35: over
## the crests, under the hazards and the deck.

## The bow ripple: 2 frames of 16x3, laid side by side across the deck's width.
@export var bow_texture: Texture2D
## The stern V: 3 frames of 32x24.
@export var stern_texture: Texture2D


func _init() -> void:
	add_to_group(&"art_view")


func _process(_delta: float) -> void:
	queue_redraw()


## The wakes drawn now, as CrossingArt.wakes gives them (in the crossing's coordinates).
func shown() -> Array[Dictionary]:
	return CrossingArt.wakes(get_parent() as Crossing)


func _draw() -> void:
	if bow_texture == null or stern_texture == null:
		return
	var tile := Vector2(bow_texture.get_width() / float(CrossingArt.BOW_FRAMES), bow_texture.get_height())
	var stern_frame := Vector2(stern_texture.get_width() / float(CrossingArt.STERN_FRAMES), stern_texture.get_height())
	for wake: Dictionary in shown():
		var bow: Rect2 = wake["bow"]
		var bow_from := Vector2(int(wake["bow_frame"]) * tile.x, 0.0)
		var x: float = 0.0
		while x < bow.size.x:
			var width: float = minf(tile.x, bow.size.x - x)
			var to := Rect2((bow.position - position + Vector2(x, 0.0)).round(), Vector2(width, tile.y))
			draw_texture_rect_region(bow_texture, to, Rect2(bow_from, Vector2(width, tile.y)))
			x += tile.x
		# A board's small wake is the full V's top middle, so it is the same V, shorter.
		var stern: Rect2 = wake["stern"]
		var from := Vector2(int(wake["stern_frame"]) * stern_frame.x + (stern_frame.x - stern.size.x) / 2.0, 0.0)
		draw_texture_rect_region(stern_texture, Rect2((stern.position - position).round(), stern.size), Rect2(from, stern.size))
