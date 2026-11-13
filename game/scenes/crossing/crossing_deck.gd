class_name CrossingDeck
extends Sprite2D
## The crossing's deck (art-pass "Crossing look", "Raft site and raft"; design.md D18, T5, T8): the
## raft frame StructureArt picks for the vessel's integrity, centred on the deck so it covers the
## deck rect, and nothing once the deck has sunk or on a swim with no vessel. Its lowest rows are
## drawn through the water-line shader, so the logs and tubes sit in the sea with a ripple along
## them instead of lying on it. It only reads its parent, every frame, so a client and a late
## joiner show the integrity they received; it is `Deck` in crossing.tscn, at z -20.

const WATER_LINE_SHADER: Shader = preload("res://scenes/art/waterline.gdshader")

## The frame row the sea comes up to: the ripple row, with the fading rows under it.
@export var water_line_row: int = 26
@export var foam_color: Color = Color.WHITE

var frame_name: StringName = StructureArt.NO_FRAME
var _frames: SpriteFrames


func _init() -> void:
	add_to_group(&"art_view")


func _ready() -> void:
	_frames = StructureArtData.standard().raft
	var water := ShaderMaterial.new()
	water.shader = WATER_LINE_SHADER
	water.set_shader_parameter(&"foam_color", foam_color)
	material = water
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var crossing := get_parent() as Crossing
	var shown: StringName = StructureArt.NO_FRAME
	if crossing != null and crossing.integrity.intact():
		shown = StructureArt.raft_frame(crossing.integrity.value)
	visible = shown != StructureArt.NO_FRAME and _frames != null and _frames.has_animation(shown)
	if not visible:
		frame_name = StructureArt.NO_FRAME
		return
	position = crossing.deck_center()
	if shown != frame_name:
		frame_name = shown
		texture = _frames.get_frame_texture(shown, 0)
		var top: float = -texture.get_size().y / 2.0
		(material as ShaderMaterial).set_shader_parameter(&"water_line_y", top + water_line_row)
