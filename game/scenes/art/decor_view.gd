class_name DecorView
extends Node2D
## The scenery cells of a handmade layout (secret-cay "He left minutes ago": the embers, the
## smoking stub, the drag mark, the cut line, the post, Platino), drawn from DecorArtData
## (art-prop-polish D6). Drawing only (`art_view`): it reads its parent island's `built.decor` and
## `layout.decor_colors` and never switches on an id, so a new decor kind is a data edit.
## - A flat look lies on the ground, drawn here at FLAT_Z: over the terrain's decals, under every
##   actor's drop shadow.
## - An upright look stands on its cell as a child of the y-sorted DecorPieces, at the actors' z,
##   so it sorts with the players and palms by its foot (art-pass "Draw order by foot position").
## - A decor id with no look still draws the tile of its layout colour.

const TILE: float = 16.0
## How far inside its cell a colour square is drawn, so the ground shows round it.
const INSET: float = 3.0
## Over the terrain's decal layer (z -10), under an actor's drop shadow (z -1).
const FLAT_Z: int = -9
const PIECES_NAME: StringName = &"DecorPieces"
const FOOT_NAME: StringName = &"Foot"
## What piece_for says a decor cell draws.
const PIECE_NONE: StringName = &"none"
const PIECE_SQUARE: StringName = &"square"
const PIECE_FLAT: StringName = &"flat"
const PIECE_UPRIGHT: StringName = &"upright"

## The looks; a test may swap them, and the pieces are drawn again.
var data: DecorArtData = DecorArtData.standard():
	set(value):
		data = value
		_drawn = null

var _drawn: IslandLayout = null
var _pieces: Node2D = null


func _init() -> void:
	add_to_group(&"art_view")
	z_index = FLAT_Z
	y_sort_enabled = true
	_pieces = Node2D.new()
	_pieces.name = PIECES_NAME
	_pieces.y_sort_enabled = true
	_pieces.z_index = -FLAT_Z
	add_child(_pieces)


func _ready() -> void:
	_follow()


func _process(_delta: float) -> void:
	_follow()


## What the decor cell `entry` ({cell, decor_id}) draws: {kind, look, colour, region}. kind is
## PIECE_FLAT or PIECE_UPRIGHT for a look that draws, PIECE_NONE for a look that draws nothing or an
## id with neither a look nor a colour, and PIECE_SQUARE for an id with only its colour. region is
## the part of a flat look's texture this cell shows.
func piece_for(entry: Dictionary) -> Dictionary:
	var source: Node = get_parent()
	var built := source.get(&"built") as IslandLayout if source != null else null
	var layout := source.get(&"layout") as IslandLayoutData if source != null else null
	var piece: Dictionary = {"kind": PIECE_NONE, "look": null, "colour": Color.TRANSPARENT, "region": Rect2()}
	if built == null or layout == null:
		return piece
	var decor_id: StringName = entry["decor_id"]
	var cell: Vector2i = entry["cell"]
	var look: DecorLook = data.look_for(decor_id, built.terrain.terrain_at(cell)) if data != null else null
	if look == null:
		var colour: Variant = layout.decor_colors.get(decor_id)
		if colour is Color:
			piece["kind"] = PIECE_SQUARE
			piece["colour"] = colour
		return piece
	piece["look"] = look
	if not look.draws():
		return piece
	piece["kind"] = PIECE_UPRIGHT if look.upright else PIECE_FLAT
	if look.texture != null:
		var size: Vector2 = look.texture.get_size()
		if look.pair:
			var east: bool = _holds(built, cell + Vector2i.LEFT, decor_id)
			piece["region"] = Rect2(Vector2(TILE if east else 0.0, 0.0), Vector2(TILE, size.y))
		else:
			piece["region"] = Rect2(Vector2.ZERO, size)
	return piece


# Rebuilds the upright pieces and redraws the flat ones when the island's layout changes.
func _follow() -> void:
	var built := get_parent().get(&"built") as IslandLayout if get_parent() != null else null
	if built == _drawn:
		return
	_drawn = built
	for child: Node in _pieces.get_children():
		child.queue_free()
		_pieces.remove_child(child)
	if built != null:
		for entry: Dictionary in built.decor:
			var piece: Dictionary = piece_for(entry)
			if piece["kind"] == PIECE_UPRIGHT:
				_pieces.add_child(_upright(piece["look"] as DecorLook, entry["cell"]))
	queue_redraw()


# An upright piece standing bottom-centre on the middle of `cell`, with its foot under it.
func _upright(look: DecorLook, cell: Vector2i) -> Node2D:
	var node: Node2D
	if look.frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = look.frames
		var animation: StringName = look.frames.get_animation_names()[0]
		sprite.play(animation)
		sprite.centered = false
		sprite.offset = StructureArt.frame_offset(look.frames.get_frame_texture(animation, 0).get_size())
		node = sprite
	else:
		var still := Sprite2D.new()
		still.texture = look.texture
		still.centered = false
		still.offset = StructureArt.frame_offset(look.texture.get_size())
		node = still
	node.name = "%s_%d_%d" % [look.decor_id, cell.x, cell.y]
	node.position = IslandLayout.cell_center(cell)
	if node is Sprite2D:
		(node as Sprite2D).offset += look.offset
	elif node is AnimatedSprite2D:
		(node as AnimatedSprite2D).offset += look.offset
	node.add_to_group(&"art_view")
	if look.foot != null:
		var foot := Sprite2D.new()
		foot.name = FOOT_NAME
		foot.texture = look.foot
		foot.show_behind_parent = true
		node.add_child(foot)
	return node


func _draw() -> void:
	var source: Node = get_parent()
	var built := source.get(&"built") as IslandLayout if source != null else null
	if built == null:
		return
	for entry: Dictionary in built.decor:
		var piece: Dictionary = piece_for(entry)
		var corner: Vector2 = Vector2(entry["cell"]) * TILE
		match piece["kind"]:
			PIECE_SQUARE:
				draw_rect(Rect2(corner + Vector2(INSET, INSET), Vector2(TILE - 2.0 * INSET, TILE - 2.0 * INSET)), piece["colour"])
			PIECE_FLAT:
				var look := piece["look"] as DecorLook
				var region: Rect2 = piece["region"]
				# Centred on the cell, bottom-aligned for a piece taller than a tile.
				var at: Vector2 = corner + Vector2((TILE - region.size.x) / 2.0, TILE - region.size.y) + look.offset
				draw_texture_rect_region(look.texture, Rect2(at, region.size), region)


static func _holds(built: IslandLayout, cell: Vector2i, decor_id: StringName) -> bool:
	for entry: Dictionary in built.decor:
		if entry["cell"] == cell and entry["decor_id"] == decor_id:
			return true
	return false
