class_name CrossingBoards
extends Node2D
## The riders' boards on a board crossing (vessel-car-board, crossing "Vessel look on the
## crossing"): one sprite under each rider whose board holds, centred on that board, with the frame
## StructureArt picks for its share of the route's board, and none once it broke. Their lowest rows
## go through the water-line shader, as the deck's do. It only reads its parent, every frame, so a
## client and a late joiner show the boards they received; the crossing never names it, and freeing
## it changes nothing the crossing does. `Boards` in crossing.tscn, at z -20 with the deck.

const WATER_LINE_SHADER: Shader = preload("res://scenes/art/waterline.gdshader")

## The frame row the sea comes up to: the ripple row, with the fading rows under it.
@export var water_line_row: int = 27
@export var foam_color: Color = Color.WHITE

var _frames: SpriteFrames
var _water: ShaderMaterial
## Rider slot -> the sprite drawing that slot's board.
var _sprites: Dictionary[int, Sprite2D] = {}


func _init() -> void:
	add_to_group(&"art_view")


func _ready() -> void:
	_frames = StructureArtData.standard().board
	_water = ShaderMaterial.new()
	_water.shader = WATER_LINE_SHADER
	_water.set_shader_parameter(&"foam_color", foam_color)
	_follow()


func _process(_delta: float) -> void:
	_follow()


## The sprite drawing `peer`'s board while it is shown, or null.
func sprite_for(peer: int) -> Sprite2D:
	var crossing := get_parent() as Crossing
	if crossing == null:
		return null
	var sprite := _sprites.get(crossing.peers().find(peer)) as Sprite2D
	return sprite if sprite != null and sprite.visible else null


func _follow() -> void:
	var crossing := get_parent() as Crossing
	var riders: Array[int] = []
	if crossing != null and crossing.is_board_route():
		riders = crossing.peers()
	for slot: int in _sprites:
		if slot >= riders.size():
			_sprites[slot].visible = false
	for slot: int in riders.size():
		var peer: int = riders[slot]
		var board := crossing.boards.get(peer) as VesselIntegrity
		var shown: StringName = StructureArt.NO_FRAME
		if board != null and board.intact():
			shown = StructureArt.vessel_frame(board.value, float(crossing.route.vessel_integrity))
		var sprite := _sprite(slot)
		sprite.visible = shown != StructureArt.NO_FRAME and _frames != null and _frames.has_animation(shown)
		if not sprite.visible:
			continue
		sprite.position = crossing.deck_rect_of(peer).get_center()
		var texture: Texture2D = _frames.get_frame_texture(shown, 0)
		if sprite.texture != texture:
			sprite.texture = texture
			_water.set_shader_parameter(&"water_line_y", -texture.get_size().y / 2.0 + water_line_row)


func _sprite(slot: int) -> Sprite2D:
	var sprite := _sprites.get(slot) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Board%d" % slot
		sprite.material = _water
		add_child(sprite)
		_sprites[slot] = sprite
	return sprite
