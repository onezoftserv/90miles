"""Build the item icons (design.md D17, D21 and K70 to K79).

From the recipe tools/art/item_icons.json, the packs under --packs and the hand-drawn sources in
--fixes it makes game/assets/art/items/<id>.png, one 16x16 icon per item. An icon is either:

- cut from a pack: the 16x16 cell at "cell" (column, row) of "file" in a source folder, with
  half-transparent pixels dropped, the colours of "map" swapped, the columns of "erase_columns"
  cleared and the piece moved by "shift" (dx, dy); then the hand-fix overlay <id>.png from the
  fixes folder is blended last when there is one (an opaque pixel replaces, #ff00ff erases); or
- "hand": a hand-drawn 16x16 source in the fixes folder.

Every icon is then remapped to the master palette (the nearest colour, never a clothing key
colour) and rimmed in the recipe's one "outline" colour, so pack and hand-made icons share the
same 1 px ring. It must be 16x16 with every opaque pixel inside the 14x14 box one pixel in from
each edge, whole alpha, palette colours only and a closed outline. No two icons may share a
silhouette. Nothing is written inside a download folder, and nothing at all when an icon is
refused.

Usage: python -I tools/art/items.py [--packs <dir>] [--recipe tools/art/item_icons.json]
       [--fixes tools/art/fixes/items] [--out game/assets/art/items]
"""
import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import compose  # noqa: E402
import palette  # noqa: E402
import png  # noqa: E402
import remap  # noqa: E402
import rim  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "item_icons.json"
DEFAULT_FIXES = HERE / "fixes" / "items"
DEFAULT_OUT = palette.ART / "items"
DOWNLOAD_FOLDERS = ("oga", "itch", "kenney")
NAME = re.compile(r"^[a-z0-9_]+$")
FILE = re.compile(r"^[A-Za-z0-9_.-]+\.png$")
ICON = 16
# The box one pixel in from each edge that the item stays inside.
BOX = (1, 1, ICON - 2, ICON - 2)


class ItemError(ValueError):
    """A recipe entry, source or icon the tool refuses."""


def load_recipe(path=DEFAULT_RECIPE):
    with open(path, encoding="utf-8") as handle:
        recipe = json.load(handle)
    if not isinstance(recipe, dict) or not isinstance(recipe.get("icons"), list):
        raise ItemError(f"{path}: a recipe is an object with an \"icons\" list")
    return recipe


def need(entry, key, where):
    if key not in entry:
        raise ItemError(f"{where}: no {key!r}")
    return entry[key]


def colour(text, where):
    try:
        return png.parse_colour(str(text))
    except ValueError as error:
        raise ItemError(f"{where}: {error}") from error


def cut(sheet, column, row, name):
    """The 16x16 cell at (column, row) of a pack sheet."""
    x, y = column * ICON, row * ICON
    if column < 0 or row < 0 or x + ICON > sheet.width or y + ICON > sheet.height:
        raise ItemError(f"{name}: cell ({column}, {row}) is off the {sheet.width}x{sheet.height} sheet")
    return sheet.crop(x, y, ICON, ICON)


def recoloured(piece, mapping):
    """A new piece: half-transparent pixels dropped, the colours of `mapping` swapped."""
    out = png.blank(piece.width, piece.height)
    for y in range(piece.height):
        for x in range(piece.width):
            pixel = piece.get(x, y)
            if pixel[3] < 255:
                continue
            out.set(x, y, mapping.get(pixel[:3], pixel[:3]) + (255,))
    return out


def erased(piece, columns):
    out = piece.copy()
    for x in columns:
        for y in range(out.height):
            out.set(x, y, (0, 0, 0, 0))
    return out


def shifted(piece, dx, dy, name):
    """The piece moved by (dx, dy); refused if an opaque pixel would leave the cell."""
    out = png.blank(piece.width, piece.height)
    for y in range(piece.height):
        for x in range(piece.width):
            pixel = piece.get(x, y)
            if not pixel[3]:
                continue
            nx, ny = x + dx, y + dy
            if not (0 <= nx < piece.width and 0 <= ny < piece.height):
                raise ItemError(f"{name}: the shift moves ({x}, {y}) off the icon")
            out.set(nx, ny, pixel)
    return out


def opaque_box(image):
    """(left, top, right, bottom) of the opaque pixels, inclusive; None when empty."""
    xs = [x for y in range(image.height) for x in range(image.width) if image.alpha(x, y)]
    ys = [y for y in range(image.height) for x in range(image.width) if image.alpha(x, y)]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def mask(image):
    return bytes(1 if image.alpha(x, y) else 0 for y in range(image.height) for x in range(image.width))


def icon_problems(image, name, palette_colours, outline):
    """Why `image` is not a shippable icon: size, box, alpha, palette and a closed outline."""
    if (image.width, image.height) != (ICON, ICON):
        return [f"{name}: {image.width}x{image.height}, not {ICON}x{ICON}"]
    box = opaque_box(image)
    if box is None:
        return [f"{name}: empty"]
    problems = []
    left, top, width, height = BOX
    if box[0] < left or box[1] < top or box[2] >= left + width or box[3] >= top + height:
        problems.append(f"{name}: spans {box}, outside the 14x14 box")
    allowed = {tuple(c[:3]) for c in palette_colours}
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if pixel[3] == 0:
                continue
            if pixel[3] < 255:
                problems.append(f"{name}: a half-transparent pixel at ({x}, {y})")
            elif pixel[:3] not in allowed:
                problems.append(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is not in the master palette")
            elif _open(image, x, y) and pixel[:3] != outline:
                problems.append(f"{name}: an edge pixel at ({x}, {y}) is not the outline colour")
    return problems


def _open(image, x, y):
    for dx, dy in rim.NEIGHBOURS:
        nx, ny = x + dx, y + dy
        if not (0 <= nx < image.width and 0 <= ny < image.height) or not image.alpha(nx, ny):
            return True
    return False


class Sources:
    """The pack folders of the recipe; files are read on first use and only from under the packs root."""

    def __init__(self, table, packs):
        self._table = table
        self._root = pathlib.Path(packs).resolve()
        self._sheets = {}

    def sheet(self, key, file_name, name):
        if key not in self._table:
            raise ItemError(f"{name}: no source named {key!r}")
        if not FILE.match(file_name):
            raise ItemError(f"{name}: {file_name!r} is not a plain PNG file name")
        path = (self._root / str(self._table[key]) / file_name).resolve()
        if not path.is_relative_to(self._root):
            raise ItemError(f"{name}: {path} is outside the packs root")
        if path not in self._sheets:
            if not path.is_file():
                raise ItemError(f"{name}: {path} not found (is --packs the folder holding itch/ and oga/?)")
            self._sheets[path] = png.read_png(path)
        return self._sheets[path]


def _hand(fixes, file_name, name):
    if not FILE.match(file_name):
        raise ItemError(f"{name}: {file_name!r} is not a plain PNG file name")
    path = pathlib.Path(fixes) / file_name
    if not path.is_file():
        raise ItemError(f"{name}: no hand-drawn source {file_name} in {fixes}")
    return png.read_png(path)


def build_icon(entry, sources, fixes, palette_colours, outline, exclude=()):
    """One icon from its recipe entry, remapped and rimmed (not yet checked)."""
    name = str(need(entry, "id", "an icon"))
    if not NAME.match(name):
        raise ItemError(f"{name!r}: an id is lower case letters, digits and underscores")
    if "hand" in entry:
        piece = _hand(fixes, str(entry["hand"]), name)
    else:
        column, row = need(entry, "cell", name) if "cell" in entry else (0, 0)
        piece = cut(sources.sheet(str(need(entry, "from", name)), str(need(entry, "file", name)), name), int(column), int(row), name)
        mapping = {colour(k, name): colour(v, name) for k, v in entry.get("map", {}).items()}
        piece = recoloured(piece, mapping)
        piece = erased(piece, [int(x) for x in entry.get("erase_columns", [])])
        dx, dy = entry.get("shift", (0, 0))
        piece = shifted(piece, int(dx), int(dy), name)
        fix = pathlib.Path(fixes) / f"{name}.png"
        if fix.is_file():
            try:
                piece = compose.apply_fix(piece, png.read_png(fix))
            except compose.PartError as error:
                raise ItemError(f"{fix}: {error}") from error
    if (piece.width, piece.height) != (ICON, ICON):
        raise ItemError(f"{name}: the source is {piece.width}x{piece.height}, not {ICON}x{ICON}")
    piece, _changes = remap.remap(piece, palette_colours, exclude=exclude)
    return rim.rim(piece, [outline], outline=outline)


def _out_folder(out, packs):
    out = pathlib.Path(out).resolve()
    for folder in DOWNLOAD_FOLDERS:
        if out.is_relative_to(pathlib.Path(packs).resolve() / folder):
            raise ItemError(f"{out} is inside the download folder {folder}/, where nothing is written")
    return out


def build(recipe, packs, fixes, out, palette_colours, exclude=(), log=print):
    """Builds and checks every icon of the recipe, then writes them all under `out`."""
    out = _out_folder(out, packs)
    sources = Sources(recipe.get("sources", {}), packs)
    outline = colour(need(recipe, "outline", "the recipe"), "the recipe")
    if outline not in {tuple(c[:3]) for c in palette_colours}:
        raise ItemError(f"the outline {png.colour_hex(outline)} is not in the master palette")
    icons = {}
    for entry in recipe["icons"]:
        image = build_icon(entry, sources, fixes, palette_colours, outline, exclude)
        name = entry["id"]
        if name in icons:
            raise ItemError(f"{name}: two icons with one id")
        icons[name] = image
    problems = []
    owners = {}
    for name, image in icons.items():
        problems.extend(icon_problems(image, name, palette_colours, outline))
        silhouette = mask(image)
        if silhouette in owners:
            problems.append(f"{owners[silhouette]} and {name} share one silhouette")
        owners.setdefault(silhouette, name)
    if problems:
        raise ItemError("; ".join(problems))
    out.mkdir(parents=True, exist_ok=True)
    for name, image in icons.items():
        png.write_png(out / f"{name}.png", image)
        log(f"items: {name}.png")
    return icons


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the folder holding itch/ and oga/")
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    args = parser.parse_args(argv)
    try:
        build(load_recipe(args.recipe), args.packs, args.fixes, args.out, palette.load_palette(args.palette),
              exclude=palette.key_ramp())
    except (ItemError, png.PngError, OSError) as error:
        print(f"items: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
