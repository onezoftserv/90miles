class_name DropShadow
extends Sprite2D
## A soft dark ellipse at an actor's feet (art-pass "Drop shadows"; design.md D15, K6, K25): a
## child of the actor's look at relative z -1, so it lies over every ground layer and under every
## actor. Drawing only (`art_view`). The look picks the size and places it.

enum Size {
	## MetroCity's 12x7 ellipse: players.
	LARGE,
	## 8x4: pick-ups.
	MEDIUM,
	## 6x3: the smallest things.
	SMALL,
}

## The ellipse of each Size, in the enum's order (set in shadow.tscn).
@export var textures: Array[Texture2D] = []
@export var size: Size = Size.LARGE:
	set(value):
		size = value
		_show_size()


func _ready() -> void:
	_show_size()


func _show_size() -> void:
	if size < textures.size():
		texture = textures[size]
