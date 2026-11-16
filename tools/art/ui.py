"""Build the HUD window kit's 9-slice PNGs and widget icons (openspec change hud-window-kit, D2).

From the recipe tools/art/ui_kit.json it draws each piece pixel by pixel from master palette
colours and writes it as an RGBA PNG with whole alpha (0 or 255) to --out. Every colour the recipe
names must be in the master palette; otherwise nothing is written and the exit code is non-zero.
Two runs give the same files byte for byte.

Piece kinds ("pieces" is a list of objects with a "name" and a "kind"):
- window: {size: [w, h], margin, outline, light, dark, fill}. A stepped-corner frame: the 4 outer
  corner pixels are transparent; ring 0 (the edge) and the 4 inner diagonal pixels are the outline;
  ring 1 is the bevel (top row and left column light, bottom row and right column dark); the rest
  is fill. "margin" is the 9-slice margin the theme uses; it is recorded here and not drawn.
- tab: a window whose last "open_rows" rows (default 2) have no bottom outline, bevel or corners:
  x0 outline, x1 light, the middle fill, the second-to-last dark, the last outline.
- selected: {size, outline, ring, fill}: a slot's selection frame; ring 0 and the inner diagonals
  in "outline", ring 1 and the four ring-2 corners in "ring", the rest fill.
- focus: {size, colour}: only ring 0 (corners cut) and the inner diagonals, the rest transparent.
- box: {size, outline, fill, tick?: {colour, pixels: [[x, y], ...]}}: a checkbox; ring 0 outline
  with the 4 outer corners transparent, fill inside, an optional tick over it.
- icon: {size, layers: [{colour, rows: ["#..", ...]}, ...]}: ASCII masks drawn in order, "#" paints.
- ramp: {highlight, base, shade}: a 1x5 strip, rows [highlight, base, base, base, shade].
- digits: {colours: [...], outline, glyphs?: {char: [5 rows of 3]}}: a strip of 12 cells (the glyph
  order "0123456789-=") of 5x7 pixels, one row of cells per colour. The 3x5 glyph sits at the
  cell offset (1, 1) in that row's colour; every other pixel 8-adjacent to a glyph pixel inside the
  cell is the outline colour. The standard glyphs are built in.

Usage: python -I tools/art/ui.py [--recipe tools/art/ui_kit.json] [--out game/assets/art/ui]
       [--palette game/assets/art/palette/master_palette.png]
"""
import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import palette  # noqa: E402
import png  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "ui_kit.json"
DEFAULT_OUT = palette.ART / "ui"
COLOUR = re.compile(r"^#[0-9a-fA-F]{6}$")
GLYPH_ORDER = "0123456789-="
CELL_W, CELL_H = 5, 7
GLYPHS = {
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", "###", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", "..#", "..#", "..#"],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "-": ["...", "...", "###", "...", "..."],
    "=": ["...", "###", "...", "###", "..."],
}


class UiError(ValueError):
    """A recipe the builder refuses."""


def need(piece, key):
    if key not in piece:
        raise UiError(f"piece {piece.get('name', '?')!r} has no \"{key}\"")
    return piece[key]


def rgba(text):
    try:
        return png.parse_colour(text) + (255,)
    except (AttributeError, ValueError) as error:
        raise UiError(f"{text!r} is not a #rrggbb colour") from error


def size_of(piece):
    value = need(piece, "size")
    if not (isinstance(value, list) and len(value) == 2 and all(isinstance(v, int) and v >= 4 for v in value)):
        raise UiError(f"piece {piece['name']!r}: size must be [w, h], each at least 4")
    return value


def colours_in(value):
    """Every #rrggbb string anywhere in a recipe value."""
    if isinstance(value, str):
        return [value] if COLOUR.match(value) else []
    if isinstance(value, list):
        return [c for item in value for c in colours_in(item)]
    if isinstance(value, dict):
        return [c for item in value.values() for c in colours_in(item)]
    return []


def check_palette(recipe, allowed):
    """Raises UiError naming every recipe colour that is not in the master palette."""
    allowed = {tuple(c[:3]) for c in allowed}
    bad = sorted({c.lower() for c in colours_in(recipe) if png.parse_colour(c) not in allowed})
    if bad:
        raise UiError("colours not in the master palette: " + ", ".join(bad))


def diagonals(w, h):
    return {(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)}


def corners_of(w, h):
    return {(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)}


def ring_of(x, y, w, h):
    return min(x, y, w - 1 - x, h - 1 - y)


def draw_window(piece):
    w, h = size_of(piece)
    o, light, dark, fill = (rgba(need(piece, k)) for k in ("outline", "light", "dark", "fill"))
    image = png.blank(w, h)
    diag = diagonals(w, h)
    cut = corners_of(w, h)
    for y in range(h):
        for x in range(w):
            if (x, y) in cut:
                continue
            ring = ring_of(x, y, w, h)
            if ring == 0 or (x, y) in diag:
                colour = o
            elif ring == 1:
                colour = light if (y == 1 or x == 1) else dark
            else:
                colour = fill
            image.set(x, y, colour)
    return image


def draw_tab(piece):
    image = draw_window(piece)
    w, h = image.width, image.height
    o, light, dark, fill = (rgba(piece[k]) for k in ("outline", "light", "dark", "fill"))
    for y in range(h - piece.get("open_rows", 2), h):
        for x in range(w):
            image.set(x, y, o if x in (0, w - 1) else light if x == 1 else dark if x == w - 2 else fill)
    return image


def draw_selected(piece):
    w, h = size_of(piece)
    o, ring, fill = (rgba(need(piece, k)) for k in ("outline", "ring", "fill"))
    image = png.blank(w, h)
    diag = diagonals(w, h)
    cut = corners_of(w, h)
    inner = {(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)}
    for y in range(h):
        for x in range(w):
            if (x, y) in cut:
                continue
            r = ring_of(x, y, w, h)
            image.set(x, y, o if r == 0 or (x, y) in diag else ring if r == 1 or (x, y) in inner else fill)
    return image


def draw_focus(piece):
    w, h = size_of(piece)
    colour = rgba(need(piece, "colour"))
    image = png.blank(w, h)
    diag = diagonals(w, h)
    cut = corners_of(w, h)
    for y in range(h):
        for x in range(w):
            if (x, y) not in cut and (ring_of(x, y, w, h) == 0 or (x, y) in diag):
                image.set(x, y, colour)
    return image


def draw_box(piece):
    w, h = size_of(piece)
    o, fill = rgba(need(piece, "outline")), rgba(need(piece, "fill"))
    image = png.blank(w, h)
    cut = corners_of(w, h)
    for y in range(h):
        for x in range(w):
            if (x, y) not in cut:
                image.set(x, y, o if ring_of(x, y, w, h) == 0 else fill)
    tick = piece.get("tick")
    if tick:
        for x, y in tick["pixels"]:
            if not (1 <= x <= w - 2 and 1 <= y <= h - 2):
                raise UiError(f"piece {piece['name']!r}: tick pixel ({x}, {y}) is outside the interior")
            image.set(x, y, rgba(tick["colour"]))
    return image


def draw_icon(piece):
    w, h = size_of(piece)
    image = png.blank(w, h)
    for layer in need(piece, "layers"):
        colour = rgba(need(layer, "colour"))
        for y, row in enumerate(need(layer, "rows")):
            for x, ch in enumerate(row):
                if ch == "#":
                    if x >= w or y >= h:
                        raise UiError(f"piece {piece['name']!r}: icon pixel outside {w}x{h}")
                    image.set(x, y, colour)
    return image


def draw_ramp(piece):
    highlight, base, shade = (rgba(need(piece, k)) for k in ("highlight", "base", "shade"))
    image = png.blank(1, 5)
    for y, colour in enumerate((highlight, base, base, base, shade)):
        image.set(0, y, colour)
    return image


def draw_digits(piece):
    colours = [rgba(c) for c in need(piece, "colours")]
    outline = rgba(need(piece, "outline"))
    glyphs = dict(GLYPHS)
    glyphs.update(piece.get("glyphs", {}))
    image = png.blank(len(GLYPH_ORDER) * CELL_W, len(colours) * CELL_H)
    for row, colour in enumerate(colours):
        for i, ch in enumerate(GLYPH_ORDER):
            shape = glyphs[ch]
            if len(shape) != 5 or any(len(r) != 3 for r in shape):
                raise UiError(f"piece {piece['name']!r}: glyph {ch!r} is not 3x5")
            on = {(gx + 1, gy + 1) for gy, r in enumerate(shape) for gx, c in enumerate(r) if c == "#"}
            for cy in range(CELL_H):
                for cx in range(CELL_W):
                    if (cx, cy) in on:
                        pixel = colour
                    elif any((cx + dx, cy + dy) in on for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                        pixel = outline
                    else:
                        continue
                    image.set(i * CELL_W + cx, row * CELL_H + cy, pixel)
    return image


DRAWERS = {
    "window": draw_window, "tab": draw_tab, "selected": draw_selected, "focus": draw_focus,
    "box": draw_box, "icon": draw_icon, "ramp": draw_ramp, "digits": draw_digits,
}


def load_recipe(path=DEFAULT_RECIPE):
    try:
        data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise UiError(f"{path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("pieces"), list):
        raise UiError(f"{path} has no \"pieces\" list")
    return data


def build(recipe, allowed):
    """{name: Image} for every piece; raises UiError, before drawing, for an off-palette colour."""
    check_palette(recipe, allowed)
    images = {}
    for piece in recipe["pieces"]:
        name, kind = piece.get("name"), piece.get("kind")
        if not isinstance(name, str) or not re.match(r"^[a-z0-9_]+$", name):
            raise UiError(f"bad piece name {name!r}")
        if name in images:
            raise UiError(f"duplicate piece {name!r}")
        if kind not in DRAWERS:
            raise UiError(f"piece {name!r}: unknown kind {kind!r}")
        images[name] = DRAWERS[kind](piece)
    return images


def write_all(images, out):
    out = pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for name, image in images.items():
        png.write_png(out / f"{name}.png", image)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    args = parser.parse_args(argv)
    try:
        images = build(load_recipe(args.recipe), palette.load_palette(args.palette))
    except (UiError, png.PngError, OSError) as error:
        print(f"ui.py: {error}", file=sys.stderr)
        return 1
    write_all(images, args.out)
    print(f"ui.py: wrote {len(images)} pieces to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
