class_name BodyLook
extends Node
## inventory-hud "Crouch cue" (design D9): how the player's body is drawn. While the body's
## movement state is crouch, its sprite is drawn at 10 of its 16 px height with its bottom edge,
## the feet, where it was; at full height otherwise. It reads the state every frame on every peer:
## the host's own simulation, a client's prediction of its own player, or the state the host
## replicates for everyone else, so teammates see a crouch too.

## The crouching body's drawn height in pixels.
const CROUCH_HEIGHT_PX: float = 10.0

## The sprite it draws lower, relative to this node.
@export var sprite_path: NodePath = ^"../Sprite"

## True while the body is drawn lowered.
var lowered: bool = false
var _sprite: Sprite2D
var _base_position: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite != null:
		_base_position = _sprite.position
		_base_scale = _sprite.scale
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Follows the body's movement state now.
func refresh() -> void:
	var body := get_parent() as PlayerBody
	var next: bool = body != null and body.movement_state == MovementStep.Move.CROUCH
	if next == lowered:
		return
	lowered = next
	_apply()


## The sprite's drawn rect in the body's own pixels (its origin at the body's).
func drawn_rect() -> Rect2:
	if _sprite == null:
		return Rect2()
	return _sprite.transform * _sprite.get_rect()


## The top of the drawn body, in the body's own pixels (negative is above its origin).
func head_y() -> float:
	return drawn_rect().position.y


# Lowered: the height scaled to CROUCH_HEIGHT_PX and the sprite moved down so its bottom edge stays.
func _apply() -> void:
	if _sprite == null:
		return
	if not lowered:
		_sprite.scale = _base_scale
		_sprite.position = _base_position
		return
	var local := _sprite.get_rect()
	var full_height: float = local.size.y * _base_scale.y
	if full_height <= 0.0:
		return
	var scale_y: float = _base_scale.y * CROUCH_HEIGHT_PX / full_height
	var bottom: float = _base_position.y + local.end.y * _base_scale.y
	_sprite.scale = Vector2(_base_scale.x, scale_y)
	_sprite.position = Vector2(_base_position.x, bottom - local.end.y * scale_y)
