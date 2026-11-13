class_name PoseRules
extends RefCounted
## Test helper: the frame layout and the pose rules of design.md C1, copied from tools/art/poses.py
## so CI checks the made part sheets without the packs (task 5.3).
##
## The frame layout is a 320x128 sheet of 10x4 cells of 32x32. Rows 0-2 are the down, side
## (facing right) and up facings, with walk in columns 0-5 (idle is column 0), crouch in 6-7 and
## swim in 8-9; row 3 holds downed in columns 0-1 and dead in column 2. Each made cell comes from a
## walk cell by its rules:
## - crouch, from walk frames 0 and 1: frame rows 21-23 and 27-29 deleted, rows above 21 down
##   6 px, rows 24-26 down 3 px, the feet row 30 kept;
## - swim: copies of walk frames 1 and 4;
## - downed: the down-facing walk frame 0 turned 90 degrees clockwise ((x, y) -> (31 - y, x)) and
##   moved 8 px down; its second frame lifts columns 8-14 (the chest) by 1 px;
## - dead: downed frame 0.

const CELL: int = 32
const SHEET_SIZE: Vector2i = Vector2i(320, 128)
const FACING_ROWS: int = 3
const WALK_FRAMES: int = 6
const CROUCH_DELETED_ROWS: Array[int] = [21, 22, 23, 27, 28, 29]
const DOWNED_DROP: int = 8
const CHEST_FIRST: int = 8
const CHEST_LAST: int = 14
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Pose family -> its cells (column, row) on the layout.
const FAMILIES: Array[StringName] = [&"walk", &"crouch", &"swim", &"downed", &"dead"]

enum Rule { CROUCH, TURN_DOWN, CHEST_LIFT }


## The cells of a pose family on the frame layout.
static func cells(family: StringName) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	match family:
		&"walk":
			for row: int in FACING_ROWS:
				for column: int in WALK_FRAMES:
					found.append(Vector2i(column, row))
		&"crouch":
			for row: int in FACING_ROWS:
				found.append_array([Vector2i(6, row), Vector2i(7, row)] as Array[Vector2i])
		&"swim":
			for row: int in FACING_ROWS:
				found.append_array([Vector2i(8, row), Vector2i(9, row)] as Array[Vector2i])
		&"downed":
			found.append_array([Vector2i(0, 3), Vector2i(1, 3)] as Array[Vector2i])
		&"dead":
			found.append(Vector2i(2, 3))
	return found


## Every used cell (33).
static func used_cells() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for family: StringName in FAMILIES:
		found.append_array(cells(family))
	return found


## Each rule-made cell: {cell, source (the walk cell), rules}.
static func made_cells() -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for row: int in FACING_ROWS:
		made.append({"cell": Vector2i(6, row), "source": Vector2i(0, row), "rules": [Rule.CROUCH]})
		made.append({"cell": Vector2i(7, row), "source": Vector2i(1, row), "rules": [Rule.CROUCH]})
		made.append({"cell": Vector2i(8, row), "source": Vector2i(1, row), "rules": []})
		made.append({"cell": Vector2i(9, row), "source": Vector2i(4, row), "rules": []})
	made.append({"cell": Vector2i(0, 3), "source": Vector2i(0, 0), "rules": [Rule.TURN_DOWN]})
	made.append({"cell": Vector2i(1, 3), "source": Vector2i(0, 0), "rules": [Rule.TURN_DOWN, Rule.CHEST_LIFT]})
	made.append({"cell": Vector2i(2, 3), "source": Vector2i(0, 0), "rules": [Rule.TURN_DOWN]})
	return made


## Where a rule sends the pixel at `at` of a 32x32 cell; (-1, -1) for a deleted row.
static func map_pixel(rule: Rule, at: Vector2i) -> Vector2i:
	match rule:
		Rule.CROUCH:
			if CROUCH_DELETED_ROWS.has(at.y):
				return Vector2i(-1, -1)
			if at.y < 21:
				return at + Vector2i(0, 6)
			if at.y < 27:
				return at + Vector2i(0, 3)
			return at
		Rule.TURN_DOWN:
			return Vector2i(CELL - 1 - at.y, at.x + DOWNED_DROP)
		Rule.CHEST_LIFT:
			if at.x >= CHEST_FIRST and at.x <= CHEST_LAST:
				return at + Vector2i(0, -1)
			return at
	return at


## A 32x32 cell with `rules` applied in turn (a pixel pushed out of the cell is dropped; the
## Python builder refuses such a part).
static func apply(rules: Array, frame: Image) -> Image:
	var current: Image = frame
	for rule: Rule in rules:
		var out: Image = Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
		for y: int in CELL:
			for x: int in CELL:
				var pixel: Color = current.get_pixel(x, y)
				if pixel.a8 == 0:
					continue
				var to: Vector2i = map_pixel(rule, Vector2i(x, y))
				if to.x >= 0 and to.x < CELL and to.y >= 0 and to.y < CELL:
					out.set_pixelv(to, pixel)
		current = out
	return current


static func cell_image(sheet: Image, cell: Vector2i) -> Image:
	var region: Image = sheet.get_region(Rect2i(cell * CELL, Vector2i(CELL, CELL)))
	if region.get_format() != Image.FORMAT_RGBA8:
		region.convert(Image.FORMAT_RGBA8)
	return region


## Opaque pixels of a 32x32 frame with a transparent 4-neighbour or one outside the frame.
static func edges(frame: Image) -> Dictionary:
	var found: Dictionary = {}
	for y: int in CELL:
		for x: int in CELL:
			if frame.get_pixel(x, y).a8 > 0 and not open_sides(frame, Vector2i(x, y)).is_empty():
				found[Vector2i(x, y)] = true
	return found


static func open_sides(frame: Image, at: Vector2i) -> Array[Vector2i]:
	var sides: Array[Vector2i] = []
	for step: Vector2i in NEIGHBOURS:
		var next: Vector2i = at + step
		if next.x < 0 or next.y < 0 or next.x >= CELL or next.y >= CELL or frame.get_pixelv(next).a8 == 0:
			sides.append(next)
	return sides


## An overlay's edge pixel whose every open side is opaque in the body frame.
static func is_covered(frame: Image, body: Image, at: Vector2i) -> bool:
	var sides: Array[Vector2i] = open_sides(frame, at)
	if sides.is_empty():
		return false
	for side: Vector2i in sides:
		if side.x < 0 or side.y < 0 or side.x >= CELL or side.y >= CELL or body.get_pixelv(side).a8 == 0:
			return false
	return true


## design.md C1's invariant on a finished part sheet, one line per problem naming the part and
## the cell: each made cell's alpha mask equals its rules applied to its walk cell's mask; a pixel
## interior both in its walk source and in the made cell keeps the rule's colour; every exposed
## edge pixel is an outline colour (`outline`, RGB keys), where, with `body`, an overlay's edge
## pixel whose open sides the body covers is not exposed. `exempt` holds the hand-fix pixels as
## Vector4i(column, row, x, y), skipped by every test.
static func invariant_problems(sheet: Image, part: String, outline: Dictionary, body: Image = null, exempt: Dictionary = {}) -> PackedStringArray:
	var problems: PackedStringArray = []
	for made: Dictionary in made_cells():
		var at: Vector2i = made["cell"]
		var walk: Image = cell_image(sheet, made["source"])
		var expected: Image = apply(made["rules"], walk)
		var interior: Dictionary = _interior_map(walk, made["rules"])
		var actual: Image = cell_image(sheet, at)
		var under: Image = cell_image(body, at) if body != null else null
		var made_edges: Dictionary = edges(actual)
		for y: int in CELL:
			for x: int in CELL:
				var here: Vector2i = Vector2i(x, y)
				if exempt.has(Vector4i(at.x, at.y, x, y)):
					continue
				var pixel: Color = actual.get_pixelv(here)
				var ruled: Color = expected.get_pixelv(here)
				if (pixel.a8 > 0) != (ruled.a8 > 0):
					problems.append("%s: cell %s pixel %s differs from the rule's mask" % [part, at, here])
					continue
				if pixel.a8 == 0:
					continue
				var exposed: bool = made_edges.has(here) and not (under != null and is_covered(actual, under, here))
				if exposed:
					if not outline.has(ArtChecks.rgb_key(pixel)):
						problems.append("%s: cell %s edge pixel %s %s is not an outline colour" % [part, at, here, ArtChecks.hex(pixel)])
				elif interior.has(here) and pixel.to_rgba32() != ruled.to_rgba32():
					problems.append("%s: cell %s pixel %s is not the rule's colour" % [part, at, here])
	return problems


# The made-cell positions whose source pixel is interior in the walk cell.
static func _interior_map(walk: Image, rules: Array) -> Dictionary:
	var marker: Image = Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	var walk_edges: Dictionary = edges(walk)
	for y: int in CELL:
		for x: int in CELL:
			if walk.get_pixel(x, y).a8 == 0:
				continue
			marker.set_pixel(x, y, Color.WHITE if not walk_edges.has(Vector2i(x, y)) else Color(0, 0, 0, 0.5))
	var moved: Image = apply(rules, marker)
	var found: Dictionary = {}
	for y: int in CELL:
		for x: int in CELL:
			if moved.get_pixel(x, y) == Color.WHITE:
				found[Vector2i(x, y)] = true
	return found


## The hand-fix pixels of tools/art/fixes/<part>.png (opaque texels), as Vector4i(column, row, x,
## y); empty when the part has no overlay. Read from the repository beside the game folder, which
## CI checks out too; the game never reads it.
static func fix_pixels(part: String) -> Dictionary:
	var found: Dictionary = {}
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/art/fixes/%s.png" % part).simplify_path()
	if not FileAccess.file_exists(path):
		return found
	var fix: Image = Image.load_from_file(path)
	if fix == null:
		return found
	for y: int in fix.get_height():
		for x: int in fix.get_width():
			if fix.get_pixel(x, y).a8 > 0:
				found[Vector4i(x / CELL, y / CELL, x % CELL, y % CELL)] = true
	return found
