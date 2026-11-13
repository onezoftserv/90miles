"""Build the structure art (design.md D18 and the notes K80 to K89).

From the recipe tools/art/structure_sheets.json, the packs under --packs and the hand-drawn
sources of tools/art/fixes/structures/, it makes each sheet the recipe lists, in
game/assets/art/: a row of frames of one size, frame i at x = i * width.

A frame is a stack of layers, drawn in order, each opaque pixel over the ones below:
- {"cut": <source>, "rect": [x, y, w, h], "at": [x, y], "flip": "h" | "v" | "hv", "turn": 90 |
  180 | 270 (clockwise, after the flip), "map": <map name>, "erase": ["#rrggbb", ...]}: a piece
  of a pack sheet. Its half-transparent pixels (the packs' baked shadows) and its "erase" colours
  are keyed out; every other colour must be named by the map, which sends it to the master
  palette, so no pack colour reaches the game unchosen.
- {"hand": <file>, "rect": [x, y, w, h], "at": [x, y]}: a piece of a hand-drawn source in the
  fixes folder, in master palette colours; #ff00ff erases what is under it.
- {"part": <name>, "at": [x, y]}: the layers of the recipe's part <name>, moved by "at".
A layer drawn partly off its frame is clipped to it. Each finished frame then gets its closed
outline (rim.py: every edge pixel to its nearest outline colour, or to the sheet's "outline"),
so a hand piece is drawn without one.

Every pixel must be whole and in the master palette, and every frame's edge in the outline set.
Nothing is written inside a download folder, and nothing at all when a sheet is refused. Run
again on the same packs and sources it gives the same files byte for byte.

Usage: python -I tools/art/structures.py [--packs <dir>] [--recipe tools/art/structure_sheets.json]
       [--fixes tools/art/fixes/structures] [--out game/assets/art]
"""
import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import palette  # noqa: E402
import png  # noqa: E402
import rim  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "structure_sheets.json"
DEFAULT_FIXES = HERE / "fixes" / "structures"
DEFAULT_OUT = palette.ART
DOWNLOAD_FOLDERS = ("oga", "itch", "kenney")
FLIPS = ("", "h", "v", "hv")
TURNS = (0, 90, 180, 270)
MAX_DEPTH = 4


class StructureError(ValueError):
    """A recipe, a source or a made sheet the builder refuses."""


def load_recipe(path=DEFAULT_RECIPE):
    try:
        data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise StructureError(f"{path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("sheets"), list):
        raise StructureError(f"{path} has no \"sheets\" list")
    return data


def need(entry, key, where):
    if not isinstance(entry, dict) or key not in entry:
        raise StructureError(f"{where} has no \"{key}\"")
    return entry[key]


def colour(text, where):
    try:
        return png.parse_colour(text)
    except (AttributeError, ValueError) as error:
        raise StructureError(f"{where}: {text!r} is not a #rrggbb colour") from error


def numbers(value, count, where):
    if not isinstance(value, list) or len(value) != count or not all(isinstance(v, int) and not isinstance(v, bool) for v in value):
        raise StructureError(f"{where}: {value!r} is not a list of {count} whole numbers")
    return value


def flipped(image, flip):
    if flip not in FLIPS:
        raise StructureError(f"flip {flip!r} is not one of h, v, hv")
    out = png.blank(image.width, image.height)
    for y in range(image.height):
        for x in range(image.width):
            sx = image.width - 1 - x if "h" in flip else x
            sy = image.height - 1 - y if "v" in flip else y
            out.set(x, y, image.get(sx, sy))
    return out


def turned(image, turn):
    """`image` turned clockwise by `turn` degrees."""
    if turn not in TURNS:
        raise StructureError(f"turn {turn!r} is not one of 0, 90, 180, 270")
    out = image
    for _ in range(turn // 90):
        source = out
        out = png.blank(source.height, source.width)
        for y in range(source.height):
            for x in range(source.width):
                out.set(source.height - 1 - y, x, source.get(x, y))
    return out


def recoloured(piece, mapping, erase, name):
    """A new piece: half-transparent pixels and `erase` colours keyed out, the rest through `mapping`."""
    out = png.blank(piece.width, piece.height)
    for y in range(piece.height):
        for x in range(piece.width):
            pixel = piece.get(x, y)
            rgb = pixel[:3]
            if pixel[3] < 255 or rgb in erase:
                continue
            if rgb not in mapping:
                raise StructureError(f"{name}: the map does not name {png.colour_hex(rgb)}, at ({x}, {y}) of the piece")
            out.set(x, y, mapping[rgb] + (255,))
    return out


def crop(sheet, rect, name):
    x, y, w, h = rect
    if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > sheet.width or y + h > sheet.height:
        raise StructureError(f"{name}: {rect} is off the {sheet.width}x{sheet.height} sheet")
    return sheet.crop(x, y, w, h)


def draw(frame, piece, at):
    """Every opaque pixel of `piece` over `frame` at `at`, clipped; #ff00ff clears instead."""
    ax, ay = at
    for y in range(piece.height):
        for x in range(piece.width):
            pixel = piece.get(x, y)
            fx, fy = x + ax, y + ay
            if pixel[3] == 0 or not (0 <= fx < frame.width and 0 <= fy < frame.height):
                continue
            frame.set(fx, fy, (0, 0, 0, 0) if pixel[:3] == palette.ERASE else pixel)


class Sources:
    """Pack sheets and hand sources, each read once."""

    def __init__(self, table, packs, fixes):
        self.table = table if isinstance(table, dict) else {}
        self.packs = pathlib.Path(packs)
        self.fixes = pathlib.Path(fixes)
        self.read = {}

    def pack(self, name):
        if name not in self.table:
            raise StructureError(f"no source named {name!r} in the recipe")
        return self._image(("pack", name), self.packs / self.table[name])

    def hand(self, name):
        if not isinstance(name, str) or pathlib.PurePosixPath(name).name != name or not name.endswith(".png"):
            raise StructureError(f"{name!r}: a hand source is a .png file name in the fixes folder")
        return self._image(("hand", name), self.fixes / name)

    def _image(self, key, path):
        if key not in self.read:
            if not path.is_file():
                raise StructureError(f"{path}: no such file")
            self.read[key] = png.read_png(path)
        return self.read[key]


def hand_piece(image, name, palette_colours):
    """`image` checked: whole pixels, each in the palette or the erase colour."""
    allowed = {tuple(c[:3]) for c in palette_colours} | {palette.ERASE}
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if pixel[3] == 0:
                continue
            if pixel[3] < 255:
                raise StructureError(f"{name}: a half-transparent pixel at ({x}, {y})")
            if pixel[:3] not in allowed:
                raise StructureError(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is not in the master palette")
    return image


def layers_of(entries, recipe, offset=(0, 0), depth=0):
    """The flat layer list of a frame, parts expanded, each with its offset added."""
    if depth > MAX_DEPTH:
        raise StructureError("parts nest too deep")
    if not isinstance(entries, list):
        raise StructureError(f"{entries!r} is not a list of layers")
    flat = []
    for layer in entries:
        at = numbers(layer.get("at", [0, 0]), 2, f"layer {layer!r}") if isinstance(layer, dict) else None
        if at is None:
            raise StructureError(f"{layer!r} is not a layer")
        moved = (at[0] + offset[0], at[1] + offset[1])
        if "part" in layer:
            parts = recipe.get("parts", {})
            if not isinstance(layer["part"], str):
                raise StructureError(f"{layer['part']!r} is not a part name")
            if layer["part"] not in parts:
                raise StructureError(f"no part named {layer['part']!r} in the recipe")
            flat.extend(layers_of(parts[layer["part"]], recipe, moved, depth + 1))
        else:
            flat.append(dict(layer, at=list(moved)))
    return flat


def build_frame(entries, size, recipe, sources, palette_colours, name):
    frame = png.blank(*size)
    maps = recipe.get("maps", {})
    for layer in layers_of(entries, recipe):
        if "cut" in layer:
            piece = crop(sources.pack(layer["cut"]), numbers(need(layer, "rect", name), 4, name), f"{name} ({layer['cut']})")
            map_name = need(layer, "map", name)
            if map_name not in maps:
                raise StructureError(f"{name}: no map named {map_name!r}")
            mapping = {colour(k, map_name): colour(v, map_name) for k, v in maps[map_name].items()}
            erase = {colour(c, name) for c in layer.get("erase", [])}
            piece = recoloured(piece, mapping, erase, f"{name} ({layer['cut']} {layer['rect']})")
        elif "hand" in layer:
            source = hand_piece(sources.hand(layer["hand"]), layer["hand"], palette_colours)
            rect = numbers(layer.get("rect", [0, 0, source.width, source.height]), 4, name)
            piece = crop(source, rect, f"{name} ({layer['hand']})")
        else:
            raise StructureError(f"{name}: a layer is a cut, a hand piece or a part: {layer!r}")
        piece = turned(flipped(piece, layer.get("flip", "")), layer.get("turn", 0))
        draw(frame, piece, layer["at"])
    return frame


def build_sheet(entry, recipe, sources, palette_colours, outline_colours):
    """The sheet of `entry`: its frames side by side, each rimmed in its own cell."""
    name = str(need(entry, "out", "a sheet"))
    width, height = numbers(need(entry, "frame", name), 2, name)
    frames = need(entry, "frames", name)
    if not isinstance(frames, list) or not frames:
        raise StructureError(f"{name} has no frames")
    sheet = png.blank(width * len(frames), height)
    for index, layers in enumerate(frames):
        sheet.paste(build_frame(layers, (width, height), recipe, sources, palette_colours, f"{name} frame {index}"), index * width, 0)
    forced = colour(entry["outline"], name) if "outline" in entry else None
    return rim.rim(sheet, outline_colours, cell=(width, height), outline=forced)


def checked(image, name, cell, palette_colours, outline_colours):
    """Raises unless every pixel is whole and in the palette and every frame edge is an outline colour."""
    allowed = {tuple(c[:3]) for c in palette_colours}
    outline = {tuple(c[:3]) for c in outline_colours}
    width, height = cell
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if pixel[3] == 0:
                continue
            if pixel[3] < 255:
                raise StructureError(f"{name}: a half-transparent pixel at ({x}, {y})")
            if pixel[:3] not in allowed:
                raise StructureError(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is not in the master palette")
            if pixel[:3] in outline:
                continue
            left, top = x - x % width, y - y % height
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (left <= nx < left + width and top <= ny < top + height) or image.alpha(nx, ny) == 0:
                    raise StructureError(f"{name}: the edge pixel ({x}, {y}) is not an outline colour")
    return image


def _out_folder(out, packs):
    out = pathlib.Path(out).resolve()
    for folder in DOWNLOAD_FOLDERS:
        if out.is_relative_to(pathlib.Path(packs).resolve() / folder):
            raise StructureError(f"{out} is inside the download folder {folder}/, where nothing is written")
    return out


def build(recipe, packs, fixes, out, palette_colours, outline_colours, log=print):
    """Builds and checks every sheet of the recipe, then writes them all under `out`."""
    out = _out_folder(out, packs)
    sources = Sources(recipe.get("sources"), packs, fixes)
    sheets = {}
    for entry in recipe["sheets"]:
        name = str(need(entry, "out", "a sheet"))
        target = (out / name).resolve()
        if not target.is_relative_to(out) or not name.endswith(".png") or name in sheets:
            raise StructureError(f"{name}: a sheet goes to a new .png under the out folder")
        image = build_sheet(entry, recipe, sources, palette_colours, outline_colours)
        sheets[name] = checked(image, name, tuple(entry["frame"]), palette_colours, outline_colours)
    for name, image in sheets.items():
        (out / name).parent.mkdir(parents=True, exist_ok=True)
        png.write_png(out / name, image)
        log(f"structures: {name} ({image.width}x{image.height})")
    return sheets


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the folder holding itch/ and oga/")
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    args = parser.parse_args(argv)
    try:
        build(load_recipe(args.recipe), args.packs, args.fixes, args.out, palette.load_palette(args.palette), palette.outline_set())
    except (StructureError, png.PngError) as error:
        print(f"structures: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
