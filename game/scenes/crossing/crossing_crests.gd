class_name CrossingCrests
extends Node2D
## art-mood-pass D6 ("Crests on the open sea"): small crests on the crossing's open water, in the deep
## ramp and #4a85a8 only, never the white and pale blue of the fin's foam, the swimmer's ring or the
## wake, so no crest reads as a fin. Where and when each shows is CrossingArt.crests: a pure read of
## the plan clock and the vessel's lateral position, so a client and a late joiner draw the host's
## crests. `Crests` in crossing.tscn, at z -38: over the sea, under the wake and the hazards.

## 3 frames side by side: rising, peak and falling.
@export var texture: Texture2D


func _init() -> void:
	add_to_group(&"art_view")


func _process(_delta: float) -> void:
	queue_redraw()


## The crests drawn now, as CrossingArt.crests gives them (in the crossing's coordinates).
func shown() -> Array[Dictionary]:
	return CrossingArt.crests(get_parent() as Crossing)


func _draw() -> void:
	if texture == null:
		return
	var size := Vector2(texture.get_width() / float(CrossingArt.CREST_FRAMES), texture.get_height())
	for crest: Dictionary in shown():
		var at: Vector2 = ((crest["at"] as Vector2) - position - size / 2.0).round()
		draw_texture_rect_region(texture, Rect2(at, size), Rect2(Vector2(int(crest["frame"]) * size.x, 0.0), size))
