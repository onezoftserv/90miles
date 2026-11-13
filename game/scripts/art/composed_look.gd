class_name ComposedLook
extends RefCounted
## One look composed from its parts (art-pass "Layered player look"; design.md C1): the atlas on the
## frame layout, its texture, the template's animations pointed at it and the head anchor of each
## pose family. Built and cached by `LookComposer`; never changed after.

## The composite on the frame layout (RGBA8, the clothing still in the key ramp).
var image: Image
var texture: ImageTexture
## A copy of the template balsero_frames.tres with every region on `texture`.
var frames: SpriteFrames
## One line per part that was missing and drawn from the default look instead, naming it.
var fallbacks: PackedStringArray = []
# Pose family -> head anchor (body-local px).
var _anchors: Dictionary[StringName, int] = {}


## The head anchor of a pose family (body-local px, negative above the body's position); the walk
## family's for a family the look does not know.
func head_anchor(family: StringName) -> int:
	return _anchors.get(family, _anchors.get(&"walk", 0))


func set_head_anchor(family: StringName, anchor_y: int) -> void:
	_anchors[family] = anchor_y
