"""Build the creature art (design.md D16, D19, D21 and K60 to K62).

From the recipe tools/art/creature_sheets.json, the packs under --packs and the hand-drawn sources
of --fixes it makes game/assets/art/creatures/<id>.png, one sheet per creature. A sheet is a size,
a frame cell and a list of layers pasted in order (an opaque pixel replaces):

- {"hand": "<file>.png"}: a hand-drawn source of the fixes folder, the sheet's own size, already
  in the master palette (the crab, the shark, and the overlay on the gull's back facing).
- {"from": "<source>", "rect": [x, y, w, h], "at": [x, y]}: a rect cut from a pack sheet, every
  colour sent through "map" (a colour it does not name must already be in the palette), with
  "drop_lone" removing pixels that touch no other, and "outline" recolouring the piece's own edge
  ring to one colour before it is pasted (the gull's frames).

Then "rim" recolours each cell's edge ring to the nearest outline colour (rim.py), and every sheet
must pass the palette, whole-alpha and outline rules cell by cell. Nothing is written inside a
download folder, and nothing at all when a sheet is refused. Run again on the same packs it gives
the same PNGs byte for byte.

Usage: python -I tools/art/creatures.py [--packs <dir>] [--recipe tools/art/creature_sheets.json]
       [--fixes tools/art/fixes/creatures] [--out game/assets/art]
"""
import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import guard  # noqa: E402
import palette  # noqa: E402
import png  # noqa: E402
import rim  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "creature_sheets.json"
DEFAULT_FIXES = HERE / "fixes" / "creatures"
DEFAULT_OUT = palette.ART
FOLDER = "creatures"
DOWNLOAD_FOLDERS = guard.DOWNLOAD_FOLDERS
NAME = re.compile(r"^[a-z0-9_]+$")
NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


class CreatureArtError(ValueError):
    """A recipe, source or sheet the builder refuses."""


def load_recipe(path=DEFAULT_RECIPE):
    try:
        recipe = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise CreatureArtError(f"{path}: {error}") from error
    if not isinstance(recipe, dict) or not isinstance(recipe.get("sheets"), list):
        raise CreatureArtError(f"{path} has no \"sheets\" list")
    return recipe


def need(entry, key, where):
    if not isinstance(entry, dict) or key not in entry:
        raise CreatureArtError(f"{where} has no \"{key}\"")
    return entry[key]


def colour(text, where):
    try:
        return png.parse_colour(str(text))
    except ValueError as error:
        raise CreatureArtError(f"{where}: {text!r} is not a #rrggbb colour") from error


def pair(value, where):
    if not (isinstance(value, list) and len(value) == 2 and all(isinstance(v, int) and v >= 0 for v in value)):
        raise CreatureArtError(f"{where}: {value!r} is not a pair of whole numbers")
    return value


class Sources:
    """The pack sheets of the recipe, read on first use and only from under the packs root."""

    def __init__(self, table, packs):
        self._table = table if isinstance(table, dict) else {}
        self._root = pathlib.Path(packs).resolve()
        self._sheets = {}

    def sheet(self, key, where):
        if key not in self._table:
            raise CreatureArtError(f"{where}: no source named {key!r}")
        if key not in self._sheets:
            relative = str(self._table[key])
            path = (self._root / relative).resolve()
            if not path.is_relative_to(self._root):
                raise CreatureArtError(f"{where}: {relative} is outside the packs root")
            if not path.is_file():
                raise CreatureArtError(f"{where}: {path} not found (is --packs the folder holding itch/ and oga/?)")
            self._sheets[key] = png.read_png(path)
        return self._sheets[key]


def recoloured(piece, mapping, allowed, where):
    """The piece with each colour mapped; a colour the map does not name must be in `allowed`."""
    out = piece.copy()
    for y in range(piece.height):
        for x in range(piece.width):
            pixel = piece.get(x, y)
            if pixel[3] == 0:
                out.set(x, y, (0, 0, 0, 0))
                continue
            if pixel[3] < 255:
                raise CreatureArtError(f"{where}: a half-transparent pixel at ({x}, {y})")
            rgb = mapping.get(pixel[:3], pixel[:3])
            if rgb not in allowed:
                raise CreatureArtError(f"{where}: the recipe does not map {png.colour_hex(pixel[:3])}, at ({x}, {y})")
            out.set(x, y, rgb + (255,))
    return out


def without_lone(piece):
    """The piece without the opaque pixels that touch no other opaque pixel."""
    out = piece.copy()
    for y in range(piece.height):
        for x in range(piece.width):
            if piece.alpha(x, y) and not any(
                0 <= x + dx < piece.width and 0 <= y + dy < piece.height and piece.alpha(x + dx, y + dy)
                for dx, dy in NEIGHBOURS
            ):
                out.set(x, y, (0, 0, 0, 0))
    return out


def pasted(sheet, piece, at, where):
    x0, y0 = at
    if x0 + piece.width > sheet.width or y0 + piece.height > sheet.height:
        raise CreatureArtError(f"{where}: a {piece.width}x{piece.height} piece at {list(at)} is off the {sheet.width}x{sheet.height} sheet")
    out = sheet.copy()
    for y in range(piece.height):
        for x in range(piece.width):
            pixel = piece.get(x, y)
            if pixel[3]:
                out.set(x0 + x, y0 + y, pixel)
    return out


def pack_layer(layer, sources, allowed, where):
    sheet = sources.sheet(str(need(layer, "from", where)), where)
    rect = need(layer, "rect", where)
    if not (isinstance(rect, list) and len(rect) == 4 and all(isinstance(v, int) and v >= 0 for v in rect)):
        raise CreatureArtError(f"{where}: rect {rect!r} is not [x, y, w, h]")
    x, y, width, height = rect
    if width == 0 or height == 0 or x + width > sheet.width or y + height > sheet.height:
        raise CreatureArtError(f"{where}: the rect {rect} is off the {sheet.width}x{sheet.height} sheet")
    mapping = {colour(k, where): colour(v, where) for k, v in dict(layer.get("map", {})).items()}
    piece = recoloured(sheet.crop(x, y, width, height), mapping, allowed, where)
    if layer.get("drop_lone", False):
        piece = without_lone(piece)
    if "outline" in layer:
        piece = rim.rim(piece, [colour(layer["outline"], where)], outline=colour(layer["outline"], where))
    return piece


def hand_layer(layer, fixes, size, where):
    name = str(need(layer, "hand", where))
    path = pathlib.Path(fixes) / name
    if pathlib.PurePosixPath(name).name != name or not name.endswith(".png") or not path.is_file():
        raise CreatureArtError(f"{where}: {name} is no hand-drawn source in {fixes}")
    piece = png.read_png(path)
    if (piece.width, piece.height) != tuple(size):
        raise CreatureArtError(f"{where}: {name} is {piece.width}x{piece.height}, not {size[0]}x{size[1]}")
    return piece


def outline_problems(image, outline, cell, name):
    """Each frame cell's edge pixels that are not an outline colour, as messages."""
    problems = []
    width, height = cell
    for top in range(0, image.height, height):
        for left in range(0, image.width, width):
            for y in range(top, top + height):
                for x in range(left, left + width):
                    pixel = image.get(x, y)
                    if not pixel[3] or pixel[:3] in outline:
                        continue
                    if any(not (left <= x + dx < left + width and top <= y + dy < top + height) or not image.alpha(x + dx, y + dy) for dx, dy in NEIGHBOURS):
                        problems.append(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is on the edge of cell ({left // width}, {top // height}) and not an outline colour")
    return problems


def checked(image, name, allowed, outline, cell):
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if pixel[3] and pixel[3] < 255:
                raise CreatureArtError(f"{name}: a half-transparent pixel at ({x}, {y})")
            if pixel[3] and pixel[:3] not in allowed:
                raise CreatureArtError(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is not in the master palette")
    problems = outline_problems(image, outline, cell, name)
    if problems:
        raise CreatureArtError(f"{problems[0]} ({len(problems)} pixels in all)")
    return image


def build_sheet(entry, sources, fixes, allowed, outline):
    sheet_id = str(need(entry, "id", "a sheet"))
    if not NAME.match(sheet_id):
        raise CreatureArtError(f"sheet id {sheet_id!r} is not lower-case letters, digits and _")
    size = pair(need(entry, "size", sheet_id), f"{sheet_id} size")
    cell = pair(need(entry, "cell", sheet_id), f"{sheet_id} cell")
    if 0 in cell or size[0] % cell[0] or size[1] % cell[1]:
        raise CreatureArtError(f"{sheet_id}: the {size[0]}x{size[1]} sheet is not whole {cell[0]}x{cell[1]} cells")
    sheet = png.blank(*size)
    for index, layer in enumerate(need(entry, "layers", sheet_id)):
        where = f"{sheet_id} layer {index}"
        if isinstance(layer, dict) and "hand" in layer:
            sheet = pasted(sheet, hand_layer(layer, fixes, size, where), (0, 0), where)
        else:
            sheet = pasted(sheet, pack_layer(layer, sources, allowed, where), pair(need(layer, "at", where), where), where)
    if entry.get("rim", False):
        sheet = rim.rim(sheet, sorted(outline), cell=tuple(cell))
    return f"{FOLDER}/{sheet_id}.png", checked(sheet, sheet_id, allowed, outline, cell)


def _out_folder(out, packs):
    return guard.out_folder(out, packs, CreatureArtError)


def build(recipe, packs, fixes, out, palette_colours, outline_colours, log=print):
    """Builds every sheet of the recipe, checks them all, then writes them under `out`."""
    out = _out_folder(out, packs)
    sources = Sources(recipe.get("sources"), packs)
    allowed = {tuple(c[:3]) for c in palette_colours}
    outline = {tuple(c[:3]) for c in outline_colours}
    sheets = dict(build_sheet(entry, sources, fixes, allowed, outline) for entry in recipe["sheets"])
    for name, image in sheets.items():
        (out / name).parent.mkdir(parents=True, exist_ok=True)
        png.write_png(out / name, image)
        log(f"creatures: {name} ({image.width}x{image.height})")
    return sheets


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the folder holding itch/ and oga/")
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    parser.add_argument("--tuning", default=str(palette.TUNING), help="art_tuning.tres, for the outline set")
    args = parser.parse_args(argv)
    try:
        build(load_recipe(args.recipe), args.packs, args.fixes, args.out, palette.load_palette(args.palette), palette.outline_set(args.tuning))
    except (CreatureArtError, png.PngError) as error:
        print(f"creatures: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
