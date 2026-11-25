class_name DinghyLook
extends Node2D
## art-guardacostas D3 (art-pass "Patrol boat and dinghy look"): a patrol boat's dinghy, a child of the
## boat's creature node that its SquadLook makes and places at `dinghy_px` every frame. The creature
## sorts its children by y, so the dinghy sorts by its own place on the beach, not the boat's. It shows
## `row` while it is between the boat and the landing and `beached` once it lies on the landing with the
## squad ashore, mirrored by the way it last rowed. Drawing only (`art_view`): it is placed by the look
## from the boat's synced state and writes nothing back.

const NODE_NAME: StringName = &"DinghyLook"
const ROW: StringName = &"row"
const BEACHED: StringName = &"beached"
const ROW_FPS: float = 4.0

var sprite: AnimatedSprite2D = null
## True when it shows mirrored (rowing toward -x).
var mirrored: bool = false
var _art: GuardacostasArt = GuardacostasArt.standard()
var _last: Vector2 = Vector2.INF


func _ready() -> void:
	add_to_group(&"art_view")
	sprite = AnimatedSprite2D.new()
	sprite.name = &"Sprite"
	sprite.centered = false
	sprite.sprite_frames = _art.dinghy_frames
	add_child(sprite)


## Shows the dinghy at `at` (session pixels, its keel's middle), `beached` or rowing.
func show_at(at: Vector2, beached: bool) -> void:
	visible = true
	if _last != Vector2.INF and absf(at.x - _last.x) > 0.01:
		mirrored = at.x < _last.x
	_last = at
	global_position = at
	if sprite == null:
		return
	sprite.flip_h = mirrored
	sprite.offset = _art.dinghy_offset(mirrored)
	var animation: StringName = BEACHED if beached else ROW
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return
	if beached:
		if sprite.animation != animation or sprite.is_playing():
			sprite.stop()
			sprite.animation = animation
		sprite.frame = 0
	elif not sprite.is_playing() or sprite.animation != animation:
		sprite.play(animation)


## Hides the dinghy (the squad is aboard).
func hide_dinghy() -> void:
	visible = false
	_last = Vector2.INF


## The animation on show.
func animation() -> StringName:
	return sprite.animation if sprite != null else &""
