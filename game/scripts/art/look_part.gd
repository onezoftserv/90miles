class_name LookPart
extends ContentData
## One layer of a player's look (art-pass "Layered player look"; design.md C1, D25): a body, an
## outfit, a hair or an item, drawn on the frame layout every part and every composed look share.
## Found by folder in res://assets/art/characters/parts/ (`id` equal to the file name), beside its
## sheet, so a new hair is a .tres and a PNG. A part with no frame in a pose it shows in is not
## offered (`problems()`).
##
## The frame layout is a 320x128 sheet of 10x4 cells of 32x32. Rows 0-2 are the down, side (facing
## right) and up facings, with walk in columns 0-5 (idle is column 0), crouch in 6-7 and swim in
## 8-9; row 3 holds downed in columns 0-1 and dead in column 2.

## Back to front: the order the composer blends the layers in. Saved as ints: append only.
enum Layer {
	BODY,
	OUTFIT,
	HAIR,
	ITEM,
}

const SHEET_SIZE: Vector2i = Vector2i(320, 128)
const CELL: Vector2i = Vector2i(32, 32)
## The pose families of the frame layout, each a set of cells.
const POSES: Array[StringName] = [&"walk", &"crouch", &"swim", &"downed", &"dead"]
const FACING_ROWS: int = 3
const WALK_FRAMES: int = 6

@export var layer: Layer = Layer.HAIR
## The part's frames on the frame layout (palette colours, lossless import).
@export var sheet: Texture2D
## Pose families this part is not drawn in; their cells must be empty. None ships this pass.
@export var hidden_in: Array[StringName] = []


## The cells (column, row) of a pose family on the frame layout.
static func pose_cells(pose: StringName) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match pose:
		&"walk":
			for row: int in FACING_ROWS:
				for column: int in WALK_FRAMES:
					cells.append(Vector2i(column, row))
		&"crouch":
			for row: int in FACING_ROWS:
				cells.append_array([Vector2i(6, row), Vector2i(7, row)] as Array[Vector2i])
		&"swim":
			for row: int in FACING_ROWS:
				cells.append_array([Vector2i(8, row), Vector2i(9, row)] as Array[Vector2i])
		&"downed":
			cells.append_array([Vector2i(0, 3), Vector2i(1, 3)] as Array[Vector2i])
		&"dead":
			cells.append(Vector2i(2, 3))
	return cells


## Why this part cannot be offered, one line per pose, naming the part: a sheet off the frame
## layout, a pose it shows in with an empty cell, or a pose it is hidden in with a drawn cell.
## Empty when the part is whole.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []
	if sheet == null:
		found.append("%s has no sheet" % id)
		return found
	var image: Image = sheet.get_image()
	if image == null or Vector2i(image.get_size()) != SHEET_SIZE:
		found.append("%s: its sheet is not the %dx%d frame layout" % [id, SHEET_SIZE.x, SHEET_SIZE.y])
		return found
	for pose: StringName in POSES:
		var hidden: bool = hidden_in.has(pose)
		var wrong: Array[Vector2i] = []
		for cell: Vector2i in pose_cells(pose):
			var empty: bool = image.get_region(Rect2i(cell * CELL, CELL)).is_invisible()
			if empty != hidden:
				wrong.append(cell)
		if wrong.is_empty():
			continue
		if hidden:
			found.append("%s is hidden in the %s pose but draws in cell(s) %s" % [id, pose, wrong])
		else:
			found.append("%s has no frame in the %s pose at cell(s) %s" % [id, pose, wrong])
	return found
