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


def colour(text, where):
    try:
        return png.parse_colour(text)
    except (AttributeError, ValueError) as error:
        raise TerrainError(f"{where}: {text!r} is not a #rrggbb colour") from error


def colour_map(table, where):
    return {colour(source, where): colour(target, where) for source, target in (table or {}).items()}


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
            self._sheets[key] = png.read_png(path)
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
    tiles = {int(mask): made(spec, f"mask {mask}") for mask, spec in need(entry, "tiles", name).items()}
    for mask, parts in entry.get("quadrants", {}).items():
        if len(parts) != 4 or any(int(part) not in tiles for part in parts):
            raise TerrainError(f"{name}: mask {mask} needs four cut masks (NW, NE, SW, SE), not {parts}")
        tiles[int(mask)] = quadrants(*(tiles[int(part)] for part in parts))
    return tiles


def build_set(entry, sources):
    """The sheet of one corner set, before its fix overlay."""
    name = str(need(entry, "id", "a set"))
    if not NAME.match(name):
        raise TerrainError(f"set id {name!r} is not lower-case letters, digits and _")
    sheet = sources.sheet(need(entry, "source", name), name)
    mapping = colour_map(entry.get("map"), name)
    erase = {colour(text, name) for text in entry.get("erase", [])}

    def made(spec, label):
        if isinstance(spec, str):
            tile = png.Image(TILE, TILE, bytes(colour(spec, name) + (255,)) * (TILE * TILE))
        else:
            tile = cut(sheet, int(spec[0]), int(spec[1]), f"{name} {label}")
        return recolour(tile, mapping, erase, f"{name} {label}")

    tiles = _set_tiles(entry, made, name)
    try:
        return set_sheet(tiles, [_variant(tiles, spec, name) for spec in entry.get("variants", [])])
    except TerrainError as error:
        raise TerrainError(f"{name}: {error}") from error


def fixed(sheet, fixes, file_name):
    """The sheet with its hand-fix overlay from the fixes folder, when there is one."""
    path = pathlib.Path(fixes) / file_name
    if not path.is_file():
        return sheet
    try:
        return compose.apply_fix(sheet, png.read_png(path))
    except compose.PartError as error:
        raise TerrainError(f"{path}: {error}") from error


def _shape(spec, sets, where):
    key = need(spec, "shape", where)
    if key not in sets:
        raise TerrainError(f"{where}: its shape set {key!r} is not built")
    return sets[key]


def build_plain(spec, sources, sets):
    """One row per plain terrain: the tile cut by the shape set's tile of mask m at column m."""
    rows = need(spec, "rows", "plain")
    shape = _shape(spec, sets, "plain")
    edges = [sheet_tile(shape, mask) for mask in range(MASKS)]
    fields = [shore_field(edge) for edge in edges]
    sheet = png.blank(MASKS * TILE, len(rows) * TILE)
    for row, entry in enumerate(rows):
        name = f"plain {entry.get('id', row)}"
        tx, ty = need(entry, "tile", name)
        whole = recolour(cut(sources.sheet(need(spec, "source", "plain"), name), tx, ty, name), colour_map(entry.get("map"), name), (), name)
        for mask in range(MASKS):
            tile = masked(whole, edges[mask])
            if "rim" in entry:
                tile = rimmed(tile, fields[mask], colour(entry["rim"], name))
            sheet.paste(tile, mask * TILE, row * TILE)
    return sheet


def build_water(spec, sources):
    sheet = sources.sheet(need(spec, "source", "water"), "water")
    x, y, width, height = need(spec, "rect", "water")
    if min(x, y) < 0 or min(width, height) < 1 or x + width > sheet.width or y + height > sheet.height:
        raise TerrainError(f"water: the rect {[x, y, width, height]} is off the {sheet.width}x{sheet.height} sheet")
    return recolour(sheet.crop(x, y, width, height), colour_map(spec.get("map"), "water"), (), "water")


def build_ramps(rows):
    """One row of colours per depth, dark to light."""
    if not rows or any(len(row) != len(rows[0]) or not row for row in rows):
        raise TerrainError("water: the ramps are not rows of one length")
    image = png.blank(len(rows[0]), len(rows))
    for y, row in enumerate(rows):
        for x, text in enumerate(row):
            image.set(x, y, colour(text, "water ramps") + (255,))
    return image


def build_foam(spec, sources, sets):
    """Frame f of the shoreline strip round the shape set's tile of mask m, at column f, row m."""
    strip = sources.sheet(need(spec, "source", "foam"), "foam")
    x0, y0 = need(spec, "origin", "foam")
    count = int(need(spec, "frames", "foam"))
    frames = []
    for index in range(count):
        x = x0 + index * int(need(spec, "step", "foam"))
        if min(x, y0) < 0 or x + TILE > strip.width or y0 + TILE > strip.height:
            raise TerrainError(f"foam: frame {index} is off the {strip.width}x{strip.height} sheet")
        frames.append(strip.crop(x, y0, TILE, TILE))
    white = colour(need(spec, "white", "foam"), "foam")
    tint = colour(need(spec, "colour", "foam"), "foam")
    fade = None
    if "fade" in spec:
        fade = (int(need(spec["fade"], "from", "foam fade")), colour(need(spec["fade"], "colour", "foam fade"), "foam"))
    shape = _shape(spec, sets, "foam")
    sheet = png.blank(count * TILE, MASKS * TILE)
    for mask in range(MASKS):
        field = shore_field(sheet_tile(shape, mask))
        for index, frame in enumerate(frames):
            piece = foam_piece(field, frame, int(need(spec, "land_rows", "foam")), white, tint, int(spec.get("feather", 0)), fade)
            sheet.paste(piece, index * TILE, mask * TILE)
    return sheet


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
    alpha = int(need(spec, "alpha", "shade"))
    edge = [int(step) for step in spec.get("edge", [])]
    if not all(0 < step <= 255 for step in edge + [alpha]):
        raise TerrainError("shade: an alpha is from 1 to 255")
    sheet = set_sheet({mask: shade_tile(sheet_tile(shape, mask), tint, alpha, edge) for mask in range(MASKS)}, [])
    if "spots" in spec:
        source = str(spec["spots"])
        path = pathlib.Path(fixes) / source
        if pathlib.PurePosixPath(source).name != source or not path.is_file():
            raise TerrainError(f"{source}: no such hand-drawn source in {fixes}")
        spots = png.read_png(path)
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


def _copies(entries, fixes, out):
    """{target: (image, partial alpha allowed)} for the hand-drawn sources of the fixes folder."""
    copies = {}
    for entry in entries:
        source = str(need(entry, "from", "a copy"))
        target = str(need(entry, "to", "a copy"))
        path = pathlib.Path(fixes) / source
        if pathlib.PurePosixPath(source).name != source or not path.is_file():
            raise TerrainError(f"{source}: no such hand-drawn source in {fixes}")
        if not (out / target).resolve().is_relative_to(out) or not target.endswith(".png"):
            raise TerrainError(f"{target}: a copy goes to a .png under the out folder")
        copies[target] = (png.read_png(path), bool(entry.get("partial_alpha", False)))
    return copies


def _out_folder(out, packs):
    out = pathlib.Path(out).resolve()
    for folder in DOWNLOAD_FOLDERS:
        if out.is_relative_to(pathlib.Path(packs).resolve() / folder):
            raise TerrainError(f"{out} is inside the download folder {folder}/, where nothing is written")
    return out


def build(recipe, packs, fixes, out, palette_colours, log=print):
    """Builds every sheet of the recipe, checks them all, then writes them under `out`."""
    out = _out_folder(out, packs)
    sources = Sources(need(recipe, "sources", "the recipe"), packs)
    sets = {}
    sheets = {}
    for entry in recipe.get("sets", []):
        sheet = build_set(entry, sources)
        sets[entry["id"]] = sheets[f"terrain/{entry['id']}.png"] = (fixed(sheet, fixes, f"{entry['id']}.png"), False)
    sets = {name: sheet for name, (sheet, _partial) in sets.items()}
    if "plain" in recipe:
        sheets["terrain/plain.png"] = (build_plain(recipe["plain"], sources, sets), False)
    if "water" in recipe:
        sheets["sea/water.png"] = (build_water(recipe["water"], sources), False)
        if "ramps" in recipe["water"]:
            sheets["sea/water_ramps.png"] = (build_ramps(recipe["water"]["ramps"]), False)
    if "foam" in recipe:
        sheets["sea/foam.png"] = (fixed(build_foam(recipe["foam"], sources, sets), fixes, "foam.png"), False)
    if "shade" in recipe:
        sheets["decals/shade.png"] = (build_shade(recipe["shade"], sets, fixes), True)
    sheets.update(_copies(recipe.get("copies", []), fixes, out))
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
    except (TerrainError, png.PngError) as error:
        print(f"terrain: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
