"""Build the terrain art (design.md D11 to D13, T13, T14 and K35 to K39).

From the recipe tools/art/terrain_tiles.json and the packs under --packs it makes, in
game/assets/art/:

- terrain/<set>.png, a 64x80 corner set: the tile of corner mask m (NW 1, NE 2, SW 4, SE 8; a
  corner counts when it is land) at column m % 4, row m // 4, and up to four variants on row 4.
  A set is cut tile by tile from a pack sheet, with the colours of "erase" keyed out (the baked
  water strip and foam rim) and every other colour sent through "map"; the tiles of "quadrants"
  (the islet and the two diagonals) are put together from quarters of the cut tiles. A "stamp"
  set draws one pack tile on the cell and a quarter of it on each land corner (the brush).
- terrain/plain.png: one row per plain terrain, the tile cut by the sand tile of mask m at
  column m (column 15 is the whole tile), with an optional rim colour on the cut edge.
- terrain/<set>_shore.png and terrain/plain_shore.png, for a set or the plain rows with a
  "shore" entry: the upper layers' tiles for shore cells, where the sand under them is cut. The
  tile of the layer's own corner mask d, kept only on the sand tile of the cell's sand mask s
  (and "inset" pixels inside its edge, with an optional rim colour on the cut), sits at column s,
  row d (plain: row 16 * terrain row + d). Only a d whose corners are all corners of s can
  occur, and s 15 has no shore, so those cells are the only ones drawn.
- sea/water.png, a rect of a pack sheet through its map, and sea/water_ramps.png, one row of
  colours per depth.
- sea/foam.png: frame f of the shoreline strip wrapped round the sand tile of mask m, at column
  f, row m. A pixel n steps out from the sand edge takes row land_rows - 1 + n of the frame, so
  the foam starts on the pixel after the sand ends.
- decals/shade.png, a 64x80 corner set of soft shadow in the sand set's outline, laid out like
  a set (a corner counts when the four cells round it are shaded), in the darkest colour at
  partial alpha and thinner on its edge pixels; row 4 holds the hand-drawn spot shades (a foot
  shade, and the two halves of a wide one) of the "spots" strip in the fixes folder.
- "copies": hand-drawn sources of the fixes folder, checked and copied.

Each set and the foam take a hand-fix overlay <name>.png from --fixes, blended last (an opaque
pixel replaces, #ff00ff erases); the plain tiles and the foam follow the fixed sand. Every colour
must be in the master palette. Nothing is written inside a download folder, and nothing at all
when a sheet is refused.

Usage: python -I tools/art/terrain.py [--packs <dir>] [--recipe tools/art/terrain_tiles.json]
       [--fixes tools/art/fixes/terrain] [--out game/assets/art]
"""
import argparse
import json
import math
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import compose  # noqa: E402
import palette  # noqa: E402
import png  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "terrain_tiles.json"
DEFAULT_FIXES = HERE / "fixes" / "terrain"
DEFAULT_OUT = palette.ART
DOWNLOAD_FOLDERS = ("oga", "itch", "kenney")
NAME = re.compile(r"^[a-z0-9_]+$")
HAND = "hand"
HAND_SOURCE = re.compile(r"^[a-z0-9_]+\.png$")
COPY_TARGET = re.compile(r"^[a-z0-9_]+/[a-z0-9_]+\.png$")
TILE = 16
HALF = TILE // 2
MASKS = 16
SET_COLUMNS = 4
VARIANT_ROW = MASKS // SET_COLUMNS
NW, NE, SW, SE = 1, 2, 4, 8
CLEAR = (0, 0, 0, 0)


class TerrainError(ValueError):
    """A recipe, a source or a made sheet the builder refuses."""


def load_recipe(path=DEFAULT_RECIPE):
    try:
        data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise TerrainError(f"{path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("sources"), dict):
        raise TerrainError(f"{path} has no \"sources\" table")
    return data


def need(entry, key, where):
    if not isinstance(entry, dict) or key not in entry:
        raise TerrainError(f"{where} has no \"{key}\"")
    return entry[key]


def section(recipe, key, kind):
    """The recipe's `key` section, which is a `kind` (dict or list); empty when it has none."""
    value = recipe.get(key, kind())
    if not isinstance(value, kind):
        raise TerrainError(f"the recipe: \"{key}\" is a {'table' if kind is dict else 'list'}, not {value!r}")
    return value


def member(entry, key, kind, where):
    """entry[key] when it is a `kind` (dict or list), else an empty one; the entry is a table."""
    value = entry.get(key, kind())
    if not isinstance(value, kind):
        raise TerrainError(f"{where}: \"{key}\" is a {'table' if kind is dict else 'list'}, not {value!r}")
    return value


def whole(value, where, key, low=None, high=None):
    """A whole number (never a bool) from `low` to `high`."""
    if not isinstance(value, int) or isinstance(value, bool) or (low is not None and value < low) or (high is not None and value > high):
        span = "" if low is None else f" from {low}" + ("" if high is None else f" to {high}")
        raise TerrainError(f"{where}: \"{key}\" is a whole number{span}, not {value!r}")
    return value


def whole_list(value, count, where, key):
    if not isinstance(value, list) or len(value) != count:
        raise TerrainError(f"{where}: \"{key}\" is {count} whole numbers, not {value!r}")
    return [whole(item, where, key) for item in value]


def mask_of(value, where):
    """A corner mask from 0 to 15, as a whole number or as digits."""
    if isinstance(value, str) and value.isdigit() and value.isascii():
        value = int(value)
    if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value < MASKS:
        raise TerrainError(f"{where}: \"{value}\" is not a mask from 0 to {MASKS - 1}")
    return value


def tile_spec(spec, where):
    """(column, row) of a [column, row] tile spec."""
    if not isinstance(spec, list) or len(spec) != 2 or not all(isinstance(n, int) and not isinstance(n, bool) for n in spec):
        raise TerrainError(f"{where}: a tile is \"#rrggbb\" or [column, row], not {spec!r}")
    return spec[0], spec[1]


def read_image(path):
    """A PNG of the packs or the fixes folder; a refusal names the file."""
    try:
        return png.read_png(path)
    except (png.PngError, OSError) as error:
        raise TerrainError(f"{path}: {error}") from error


def colour(text, where):
    try:
        return png.parse_colour(text)
    except (AttributeError, ValueError) as error:
        raise TerrainError(f"{where}: {text!r} is not a #rrggbb colour") from error


def colour_map(entry, where):
    """The colours of the entry's "map" table, source to target."""
    table = member(entry, "map", dict, where)
    return {colour(source, where): colour(target, where) for source, target in table.items()}


def cut(sheet, tx, ty, name="tile"):
    """The 16 px tile at column tx, row ty of a pack sheet."""
    x, y = tx * TILE, ty * TILE
    if tx < 0 or ty < 0 or x + TILE > sheet.width or y + TILE > sheet.height:
        raise TerrainError(f"{name}: tile ({tx}, {ty}) is off the {sheet.width}x{sheet.height} sheet")
    return sheet.crop(x, y, TILE, TILE)


def recolour(tile, mapping, erase=(), name="tile"):
    """A new tile: `erase` colours and half-transparent pixels keyed out, the rest through `mapping`."""
    out = png.blank(tile.width, tile.height)
    for y in range(tile.height):
        for x in range(tile.width):
            pixel = tile.get(x, y)
            rgb = pixel[:3]
            if pixel[3] < 255 or rgb in erase:
                continue
            if rgb not in mapping:
                raise TerrainError(f"{name}: the recipe does not name {png.colour_hex(rgb)}, at ({x}, {y})")
            out.set(x, y, mapping[rgb] + (255,))
    return out


def quadrants(north_west, north_east, south_west, south_east):
    """A tile whose four quarters come from the same quarter of four tiles."""
    out = png.blank(TILE, TILE)
    for tile, (x, y) in ((north_west, (0, 0)), (north_east, (HALF, 0)), (south_west, (0, HALF)), (south_east, (HALF, HALF))):
        out.paste(tile.crop(x, y, HALF, HALF), x, y)
    return out


def _stamp(out, stamp, dx, dy):
    for y in range(stamp.height):
        for x in range(stamp.width):
            pixel = stamp.get(x, y)
            if pixel[3] and 0 <= x + dx < out.width and 0 <= y + dy < out.height:
                out.set(x + dx, y + dy, pixel)


def stamped(stamp, mask):
    """The stamp on the cell, with a stamp centred on each land corner: north ones behind, south ones in front."""
    out = png.blank(TILE, TILE)
    for bit, offset in ((NW, (-HALF, -HALF)), (NE, (HALF, -HALF)), (0, (0, 0)), (SW, (-HALF, HALF)), (SE, (HALF, HALF))):
        if bit == 0 or mask & bit:
            _stamp(out, stamp, *offset)
    return out


def mirrored(tile):
    out = png.blank(tile.width, tile.height)
    for y in range(tile.height):
        for x in range(tile.width):
            out.set(tile.width - 1 - x, y, tile.get(x, y))
    return out


def set_sheet(tiles, variants):
    """The 64x80 sheet of a corner set: mask m at (m % 4, m // 4), the variants on row 4."""
    if len(variants) > SET_COLUMNS:
        raise TerrainError(f"{len(variants)} variants, and row {VARIANT_ROW} holds {SET_COLUMNS}")
    sheet = png.blank(SET_COLUMNS * TILE, (VARIANT_ROW + 1) * TILE)
    for mask in range(MASKS):
        if mask not in tiles:
            raise TerrainError(f"no tile for mask {mask}")
        sheet.paste(tiles[mask], (mask % SET_COLUMNS) * TILE, (mask // SET_COLUMNS) * TILE)
    for column, tile in enumerate(variants):
        sheet.paste(tile, column * TILE, VARIANT_ROW * TILE)
    return sheet


def sheet_tile(sheet, mask):
    return sheet.crop((mask % SET_COLUMNS) * TILE, (mask // SET_COLUMNS) * TILE, TILE, TILE)


def masked(tile, shape):
    """The tile, kept only where `shape` is drawn."""
    out = tile.copy()
    for y in range(tile.height):
        for x in range(tile.width):
            if not shape.alpha(x, y):
                out.set(x, y, CLEAR)
    return out


def _shore_point(x, y, others, on_land):
    dx, dy = min(((ox - x, oy - y) for ox, oy in others), key=lambda d: (d[0] * d[0] + d[1] * d[1], abs(d[0])))
    steps = int(math.sqrt(dx * dx + dy * dy) + 0.5)
    return (x, y, 1 - steps if on_land else steps, x if abs(dy) >= abs(dx) else y)


def shore_field(sand):
    """(x, y, steps, along) for each pixel of a sand tile: steps from the sand edge (1 on the first
    water pixel, 0 on the last sand pixel) and the place along the shore; empty with no shore."""
    cells = [(x, y) for y in range(sand.height) for x in range(sand.width)]
    land = [cell for cell in cells if sand.alpha(*cell)]
    water = [cell for cell in cells if not sand.alpha(*cell)]
    if not land or not water:
        return []
    return [_shore_point(x, y, land, False) for x, y in water] + [_shore_point(x, y, water, True) for x, y in land]


def foam_piece(field, frame, land_rows, white, tint, feather=0, fade=None):
    """One frame of a straight shoreline strip wrapped round a sand tile's edge. From `feather`
    steps out, every other pixel is dropped, so the band does not end on a straight cut; with
    `fade` (steps, colour) the foam takes that colour from that many steps out."""
    piece = png.blank(TILE, TILE)
    for x, y, steps, along in field:
        row = land_rows - 1 + steps
        if not 0 <= row < frame.height or (feather and steps >= feather and (along + steps) % 2):
            continue
        pixel = frame.get(along % frame.width, row)
        if pixel[3] and pixel[:3] == white:
            piece.set(x, y, (fade[1] if fade and steps >= fade[0] else tint) + (255,))
    return piece


def rimmed(tile, field, rim):
    """The tile with the rim colour on its pixels that touch the cut edge of a shape's shore field."""
    out = tile.copy()
    for x, y, steps, _along in field:
        if steps == 0 and out.alpha(x, y):
            out.set(x, y, rim + (255,))
    return out


def shore_cut(tile, shape, field, inset=0, rim=None):
    """The tile kept only where `shape` is drawn and at least `inset` pixels inside its edge
    (`field` is the shape's shore field), with the rim colour on the kept pixels on that cut."""
    depth = {(x, y): -steps for x, y, steps, _along in field}
    out = png.blank(tile.width, tile.height)
    for y in range(tile.height):
        for x in range(tile.width):
            if not tile.alpha(x, y) or not shape.alpha(x, y):
                continue
            inside = depth.get((x, y), TILE)
            if inside < inset:
                continue
            out.set(x, y, rim + (255,) if rim is not None and inside == inset else tile.get(x, y))
    return out


def shore_sheet(rows, shape, inset=0, rims=None):
    """Column s, row 16 * r + d: tile d of `rows[r]` (16 tiles by own corner mask) cut by the
    shape set's tile of mask s, for every d whose corners are all corners of s, s below 15."""
    sheet = png.blank(MASKS * TILE, len(rows) * MASKS * TILE)
    for s in range(MASKS - 1):
        edge = sheet_tile(shape, s)
        field = shore_field(edge)
        for r, tiles in enumerate(rows):
            for d in range(MASKS):
                if d & ~s == 0:
                    sheet.paste(shore_cut(tiles[d], edge, field, inset, rims[r] if rims else None), s * TILE, (r * MASKS + d) * TILE)
    return sheet


def _shore_spec(spec, sets, where):
    if not isinstance(spec, dict):
        raise TerrainError(f"{where}: \"shore\" is a table, not {spec!r}")
    inset = spec.get("inset", 0)
    if not isinstance(inset, int) or isinstance(inset, bool) or not 0 <= inset < HALF:
        raise TerrainError(f"{where}: \"inset\" is a whole number of pixels from 0 to {HALF - 1}")
    return _shape(spec, sets, where), inset


class Sources:
    """The pack sheets of the recipe, read on first use and only from under the packs root."""

    def __init__(self, table, packs):
        self._table = table
        self._root = pathlib.Path(packs).resolve()
        self._sheets = {}

    def sheet(self, key, name):
        if key not in self._table:
            raise TerrainError(f"{name}: no source named {key!r}")
        if key not in self._sheets:
            relative = str(self._table[key])
            path = (self._root / relative).resolve()
            if not path.is_relative_to(self._root):
                raise TerrainError(f"{name}: {relative} is outside the packs root")
            if not path.is_file():
                raise TerrainError(f"{name}: {path} not found (is --packs the folder holding itch/ and oga/?)")
            self._sheets[key] = read_image(path)
        return self._sheets[key]


def _variant(tiles, spec, name):
    text = str(spec)
    try:
        tile = tiles[int(text.rstrip("h"))]
    except (KeyError, ValueError) as error:
        raise TerrainError(f"{name}: variant {spec!r} is not a mask of the set (an h after it mirrors it)") from error
    return mirrored(tile) if text.endswith("h") else tile


def _set_tiles(entry, made, name):
    if "stamp" in entry:
        stamp = made(entry["stamp"], "stamp")
        return {mask: stamped(stamp, mask) for mask in range(MASKS)}
    listed = need(entry, "tiles", name)
    if not isinstance(listed, dict):
        raise TerrainError(f"{name}: \"tiles\" is a table of masks, not {listed!r}")
    tiles = {mask_of(key, f"{name} tiles"): made(spec, f"mask {key}") for key, spec in listed.items()}
    for key, parts in member(entry, "quadrants", dict, name).items():
        mask = mask_of(key, f"{name} quadrants")
        if not isinstance(parts, list) or len(parts) != 4:
            raise TerrainError(f"{name} quadrants: \"{key}\" needs four cut masks (NW, NE, SW, SE), not {parts}")
        cut_masks = [mask_of(part, f"{name} quadrants") for part in parts]
        if any(part not in tiles for part in cut_masks):
            raise TerrainError(f"{name} quadrants: \"{key}\" needs four cut masks (NW, NE, SW, SE), not {parts}")
        tiles[mask] = quadrants(*(tiles[part] for part in cut_masks))
    return tiles


def build_set(entry, sources):
    """The sheet of one corner set, before its fix overlay."""
    name = str(need(entry, "id", "a set"))
    if not NAME.match(name):
        raise TerrainError(f"set id {name!r} is not lower-case letters, digits and _")
    sheet = sources.sheet(need(entry, "source", name), name)
    mapping = colour_map(entry, name)
    erase = {colour(text, name) for text in member(entry, "erase", list, name)}

    def made(spec, label):
        if spec == HAND:
            return png.blank(TILE, TILE)
        if isinstance(spec, str):
            tile = png.Image(TILE, TILE, bytes(colour(spec, name) + (255,)) * (TILE * TILE))
        else:
            tile = cut(sheet, *tile_spec(spec, f"{name} {label}"), f"{name} {label}")
        return recolour(tile, mapping, erase, f"{name} {label}")

    tiles = _set_tiles(entry, made, name)
    try:
        return set_sheet(tiles, [_variant(tiles, spec, name) for spec in member(entry, "variants", list, name)])
    except TerrainError as error:
        raise TerrainError(f"{name}: {error}") from error


def hand_cells(entry):
    """The (column, row) cells of a set's sheet whose tile is "hand": blank, drawn whole by its overlay."""
    tiles = entry.get("tiles")
    if not isinstance(tiles, dict):
        return set()
    return {(mask % SET_COLUMNS, mask // SET_COLUMNS) for mask in (mask_of(key, "tiles") for key, spec in tiles.items() if spec == HAND)}


def fixed(sheet, fixes, file_name, hand=()):
    """The sheet with its hand-fix overlay from the fixes folder, when there is one. The overlay
    holds hand pixels only: one equal to the built pixel under it is refused, except in a `hand`
    cell, which the overlay must cover whole."""
    path = pathlib.Path(fixes) / file_name
    if not path.is_file():
        return sheet
    overlay = read_image(path)
    try:
        out = compose.apply_fix(sheet, overlay)
    except compose.PartError as error:
        raise TerrainError(f"{path}: {error}") from error
    covered = {}
    for y in range(overlay.height):
        for x in range(overlay.width):
            cell = (x // TILE, y // TILE)
            if not overlay.alpha(x, y):
                continue
            covered[cell] = covered.get(cell, 0) + 1
            if cell not in hand and (out.get(x, y) == sheet.get(x, y) or not (out.alpha(x, y) or sheet.alpha(x, y))):
                raise TerrainError(f"{file_name}: the overlay pixel ({x}, {y}) in cell {cell} is what the tool already builds, so it is not a hand pixel")
    for cell in sorted(hand):
        missing = TILE * TILE - covered.get(cell, 0)
        if missing:
            raise TerrainError(f"{file_name}: hand cell {cell} is not drawn whole by the overlay ({missing} of {TILE * TILE} pixels missing)")
    return out


def _shape(spec, sets, where):
    key = need(spec, "shape", where)
    if key not in sets:
        raise TerrainError(f"{where}: its shape set {key!r} is not built")
    return sets[key]


def build_plain(spec, sources, sets):
    """One row per plain terrain: the tile cut by the shape set's tile of mask m at column m."""
    rows = need(spec, "rows", "plain")
    if not isinstance(rows, list) or not rows:
        raise TerrainError(f"plain: \"rows\" is a list of at least one row, not {rows!r}")
    shape = _shape(spec, sets, "plain")
    edges = [sheet_tile(shape, mask) for mask in range(MASKS)]
    fields = [shore_field(edge) for edge in edges]
    sheet = png.blank(MASKS * TILE, len(rows) * TILE)
    for row, entry in enumerate(rows):
        if not isinstance(entry, dict):
            raise TerrainError(f"plain row {row} is not a table: {entry!r}")
        name = f"plain {entry.get('id', row)}"
        tx, ty = tile_spec(need(entry, "tile", name), name)
        full = recolour(cut(sources.sheet(need(spec, "source", "plain"), name), tx, ty, name), colour_map(entry, name), (), name)
        for mask in range(MASKS):
            tile = masked(full, edges[mask])
            if "rim" in entry:
                tile = rimmed(tile, fields[mask], colour(entry["rim"], name))
            sheet.paste(tile, mask * TILE, row * TILE)
    return sheet


def build_water(spec, sources):
    sheet = sources.sheet(need(spec, "source", "water"), "water")
    x, y, width, height = whole_list(need(spec, "rect", "water"), 4, "water", "rect")
    if min(x, y) < 0 or min(width, height) < 1 or x + width > sheet.width or y + height > sheet.height:
        raise TerrainError(f"water: the rect {[x, y, width, height]} is off the {sheet.width}x{sheet.height} sheet")
    return recolour(sheet.crop(x, y, width, height), colour_map(spec, "water"), (), "water")


def build_ramps(rows):
    """One row of colours per depth, dark to light."""
    if not isinstance(rows, list) or not rows or any(not isinstance(row, list) or not row or len(row) != len(rows[0]) for row in rows):
        raise TerrainError(f"water ramps: not rows of colours of one length, {rows!r}")
    image = png.blank(len(rows[0]), len(rows))
    for y, row in enumerate(rows):
        for x, text in enumerate(row):
            image.set(x, y, colour(text, "water ramps") + (255,))
    return image


def build_foam(spec, sources, sets):
    """Frame f of the shoreline strip round the shape set's tile of mask m, at column f, row m."""
    strip = sources.sheet(need(spec, "source", "foam"), "foam")
    x0, y0 = whole_list(need(spec, "origin", "foam"), 2, "foam", "origin")
    count = whole(need(spec, "frames", "foam"), "foam", "frames", low=1)
    step = whole(need(spec, "step", "foam"), "foam", "step", low=1)
    land_rows = whole(need(spec, "land_rows", "foam"), "foam", "land_rows", low=0)
    frames = []
    for index in range(count):
        x = x0 + index * step
        if min(x, y0) < 0 or x + TILE > strip.width or y0 + TILE > strip.height:
            raise TerrainError(f"foam: frame {index} is off the {strip.width}x{strip.height} sheet")
        frames.append(strip.crop(x, y0, TILE, TILE))
    white = colour(need(spec, "white", "foam"), "foam")
    tint = colour(need(spec, "colour", "foam"), "foam")
    fade = None
    if "fade" in spec:
        if not isinstance(spec["fade"], dict):
            raise TerrainError(f"foam: \"fade\" is a table, not {spec['fade']!r}")
        fade = (whole(need(spec["fade"], "from", "foam fade"), "foam fade", "from", low=0), colour(need(spec["fade"], "colour", "foam fade"), "foam"))
    shape = _shape(spec, sets, "foam")
    sheet = png.blank(count * TILE, MASKS * TILE)
    for mask in range(MASKS):
        field = shore_field(sheet_tile(shape, mask))
        for index, frame in enumerate(frames):
            piece = foam_piece(field, frame, land_rows, white, tint, int(spec.get("feather", 0)), fade)
            sheet.paste(piece, index * TILE, mask * TILE)
    return sheet


def hand_source(source, fixes):
    """The path of a hand-drawn source: a bare lower-case .png name, a file of the fixes folder."""
    if not isinstance(source, str) or not HAND_SOURCE.match(source):
        raise TerrainError(f"{source!r}: a hand-drawn source is a lower-case name ending in .png, in {fixes}")
    path = pathlib.Path(fixes) / source
    if not path.is_file():
        raise TerrainError(f"{source}: no such hand-drawn source in {fixes}")
    return path


def shade_tile(shape, tint, alpha, edge):
    """A shadow in the shape of a tile: the tint at `alpha`, and at the alphas of `edge` on the
    pixels nearest the shape's edge (the outermost first), so it ends softly."""
    depth = {(x, y): -steps for x, y, steps, _along in shore_field(shape)}
    out = png.blank(shape.width, shape.height)
    for y in range(shape.height):
        for x in range(shape.width):
            if shape.alpha(x, y):
                inside = depth.get((x, y), len(edge))
                out.set(x, y, tint + (edge[inside] if inside < len(edge) else alpha,))
    return out


def build_shade(spec, sets, fixes):
    """The shade decals as a corner set in the shape set's outline (mask m at column m % 4, row
    m // 4), for a block of shaded cells, with the hand-drawn spot shades of "spots" on row 4."""
    shape = _shape(spec, sets, "shade")
    tint = colour(need(spec, "colour", "shade"), "shade")
    alpha = whole(need(spec, "alpha", "shade"), "shade", "alpha", low=1, high=255)
    edge = [whole(step, "shade", "edge", low=1, high=255) for step in member(spec, "edge", list, "shade")]
    sheet = set_sheet({mask: shade_tile(sheet_tile(shape, mask), tint, alpha, edge) for mask in range(MASKS)}, [])
    if "spots" in spec:
        source = spec["spots"]
        spots = read_image(hand_source(source, fixes))
        if (spots.width, spots.height) != (SET_COLUMNS * TILE, TILE):
            raise TerrainError(f"{source} is {spots.width}x{spots.height}, and the spot row is {SET_COLUMNS * TILE}x{TILE}")
        sheet.paste(spots, 0, VARIANT_ROW * TILE)
    return sheet


def checked(image, name, palette_colours, partial_alpha=False):
    """Raises unless every pixel is whole (or, with `partial_alpha`, the darkest colour) and in the palette."""
    allowed = {tuple(entry[:3]) for entry in palette_colours}
    shadow = palette.darkest(sorted(allowed))
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if pixel[3] == 0:
                continue
            if pixel[3] < 255 and not (partial_alpha and pixel[:3] == tuple(shadow[:3])):
                raise TerrainError(f"{name}: a half-transparent pixel at ({x}, {y})")
            if pixel[:3] not in allowed:
                raise TerrainError(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is not in the master palette")
    return image


def _copies(entries, fixes):
    """{target: (image, partial alpha allowed)} for the hand-drawn sources of the fixes folder."""
    copies = {}
    for entry in entries:
        source = need(entry, "from", "a copy")
        target = need(entry, "to", "a copy")
        path = hand_source(source, fixes)
        if not isinstance(target, str) or not COPY_TARGET.match(target):
            raise TerrainError(f"{target!r}: a copy goes to <folder>/<name>.png, in lower case")
        if target in copies:
            raise TerrainError(f"{target} is made twice")
        copies[target] = (read_image(path), False)
    return copies


def _out_folder(out, packs):
    out = pathlib.Path(out).resolve()
    for folder in DOWNLOAD_FOLDERS:
        if out.is_relative_to(pathlib.Path(packs).resolve() / folder):
            raise TerrainError(f"{out} is inside the download folder {folder}/, where nothing is written")
    return out


def _refuse_final_paths(names, out, packs, fixes):
    """Raises when a sheet's final path is under a download folder of the packs root or the fixes folder."""
    fixes = pathlib.Path(fixes).resolve()
    for name in names:
        path = (out / name).resolve()
        for folder in DOWNLOAD_FOLDERS:
            if path.is_relative_to(pathlib.Path(packs).resolve() / folder):
                raise TerrainError(f"{name}: would be written inside the download folder {folder}/, where nothing is written")
        if path.is_relative_to(fixes):
            raise TerrainError(f"{name}: would be written inside the fixes folder {fixes}, which holds hand sources")


def build(recipe, packs, fixes, out, palette_colours, log=print):
    """Builds every sheet of the recipe, checks them all, then writes them under `out`."""
    out = _out_folder(out, packs)
    sources = Sources(need(recipe, "sources", "the recipe"), packs)
    sheets = {}

    def add(name, image, partial_alpha=False):
        if name in sheets:
            raise TerrainError(f"{name} is made twice")
        sheets[name] = (image, partial_alpha)

    sets = {}
    entries = section(recipe, "sets", list)
    for entry in entries:
        sheet = build_set(entry, sources)
        sets[entry["id"]] = fixed(sheet, fixes, f"{entry['id']}.png", hand_cells(entry))
        add(f"terrain/{entry['id']}.png", sets[entry["id"]])
    for entry in entries:
        if "shore" in entry:
            name = f"{entry['id']} shore"
            shape, inset = _shore_spec(entry["shore"], sets, name)
            rim = colour(entry["shore"]["rim"], name) if "rim" in entry["shore"] else None
            tiles = [sheet_tile(sets[entry["id"]], mask) for mask in range(MASKS)]
            add(f"terrain/{entry['id']}_shore.png", shore_sheet([tiles], shape, inset, [rim]))
    for key, kind in (("plain", dict), ("water", dict), ("foam", dict), ("shade", dict)):
        if key in recipe:
            section(recipe, key, kind)
    if "plain" in recipe:
        plain = build_plain(recipe["plain"], sources, sets)
        add("terrain/plain.png", plain)
        if "shore" in recipe["plain"]:
            spec = dict(recipe["plain"]["shore"]) if isinstance(recipe["plain"]["shore"], dict) else recipe["plain"]["shore"]
            if isinstance(spec, dict):
                spec.setdefault("shape", recipe["plain"].get("shape"))
            shape, inset = _shore_spec(spec, sets, "plain shore")
            entries = recipe["plain"]["rows"]
            rows = [[plain.crop(mask * TILE, row * TILE, TILE, TILE) for mask in range(MASKS)] for row in range(len(entries))]
            rims = [colour(entry["rim"], "plain shore") if "rim" in entry else None for entry in entries]
            add("terrain/plain_shore.png", shore_sheet(rows, shape, inset, rims))
    if "water" in recipe:
        add("sea/water.png", build_water(recipe["water"], sources))
        if "ramps" in recipe["water"]:
            add("sea/water_ramps.png", build_ramps(recipe["water"]["ramps"]))
    if "foam" in recipe:
        foam = fixed(build_foam(recipe["foam"], sources, sets), fixes, "foam.png")
        if foam.is_empty():
            raise TerrainError("foam: no pixel at all (is \"white\" a colour of the strip?)")
        add("sea/foam.png", foam)
    if "shade" in recipe:
        add("decals/shade.png", build_shade(recipe["shade"], sets, fixes), True)
    for target, (image, partial_alpha) in _copies(section(recipe, "copies", list), fixes).items():
        add(target, image, partial_alpha)
    _refuse_final_paths(sheets, out, packs, fixes)
    for name, (image, partial_alpha) in sheets.items():
        checked(image, name, palette_colours, partial_alpha)
    for name, (image, _partial) in sheets.items():
        (out / name).parent.mkdir(parents=True, exist_ok=True)
        png.write_png(out / name, image)
        log(f"terrain: {name} ({image.width}x{image.height})")
    return {name: image for name, (image, _partial) in sheets.items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the folder holding itch/ and oga/")
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    args = parser.parse_args(argv)
    try:
        build(load_recipe(args.recipe), args.packs, args.fixes, args.out, palette.load_palette(args.palette))
    except (TerrainError, png.PngError, OSError) as error:
        print(f"terrain: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
