"""Build the small effect sprites (openspec change art-sprite-polish D1).

From the recipe tools/art/fx.json it draws each piece from master palette colours and writes it as
an RGBA PNG to <--out>/<its "folder">/<its name>.png, --out being the art root. Every colour the
recipe names must be in the master palette; otherwise nothing is written and the exit code is
non-zero. Two runs give the same files byte for byte, and nothing is written outside --out.

Piece kinds ("pieces" is a list of objects with a "name" and a "kind"):
- ring: {size: [w, h], frames, front, back, dash, gap}: a 1 px oval outline in a w x h box, drawn
  `frames` times side by side. Walking round the oval from its left end, runs of `dash` pixels are
  drawn and `gap` pixels left out, and the runs move one pixel along each frame, so the frames loop
  when `frames` is dash + gap. A pixel below the oval's middle row (nearer the viewer) takes
  `front`, the rest `back`.

Usage: python -I tools/art/fx.py [--recipe tools/art/fx.json] [--out game/assets/art]
       [--palette game/assets/art/palette/master_palette.png]
"""
import argparse
import json
import math
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import palette  # noqa: E402
import png  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "fx.json"
DEFAULT_OUT = palette.ART
FOLDERS = ("fx", "shadows")
COLOUR = re.compile(r"^#[0-9a-fA-F]{6}$")
NAME = re.compile(r"^[a-z][a-z0-9_]*$")


class FxError(ValueError):
    """A recipe the builder refuses."""


def need(piece, key):
    if key not in piece:
        raise FxError(f"piece {piece.get('name', '?')!r} has no \"{key}\"")
    return piece[key]


def whole(piece, key, low):
    value = need(piece, key)
    if not isinstance(value, int) or isinstance(value, bool) or value < low:
        raise FxError(f"piece {piece['name']!r}: \"{key}\" must be a whole number of at least {low}")
    return value


def rgba(text):
    try:
        return png.parse_colour(text) + (255,)
    except (AttributeError, ValueError) as error:
        raise FxError(f"{text!r} is not a #rrggbb colour") from error


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
    """Raises FxError naming every recipe colour that is not in the master palette."""
    allowed = {tuple(c[:3]) for c in allowed}
    bad = sorted({c.lower() for c in colours_in(recipe) if png.parse_colour(c) not in allowed})
    if bad:
        raise FxError("colours not in the master palette: " + ", ".join(bad))


def oval_outline(w, h):
    """The pixels of a w x h box on the edge of the oval it holds: inside the oval (by pixel
    centre) with a 4-neighbour outside it or off the box, in order round the oval from its left
    end, clockwise on screen (over the top first)."""
    cx, cy = w / 2.0, h / 2.0

    def inside(x, y):
        if not (0 <= x < w and 0 <= y < h):
            return False
        return ((x + 0.5 - cx) / cx) ** 2 + ((y + 0.5 - cy) / cy) ** 2 <= 1.0

    edge = [(x, y) for y in range(h) for x in range(w)
            if inside(x, y) and not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]

    def turn(at):
        x, y = at
        angle = math.atan2((y + 0.5 - cy) / cy, (x + 0.5 - cx) / cx)  # 0 at the right end, +pi/2 below
        return ((angle + math.pi) % (2 * math.pi), x, y)  # from the left end, over the top first

    return sorted(edge, key=turn)


def draw_ring(piece):
    size = need(piece, "size")
    if not (isinstance(size, list) and len(size) == 2 and all(isinstance(v, int) and v >= 4 for v in size)):
        raise FxError(f"piece {piece['name']!r}: size must be [w, h], each at least 4")
    w, h = size
    frames = whole(piece, "frames", 1)
    dash = whole(piece, "dash", 1)
    gap = whole(piece, "gap", 1)
    front, back = rgba(need(piece, "front")), rgba(need(piece, "back"))
    outline = oval_outline(w, h)
    image = png.blank(w * frames, h)
    for frame in range(frames):
        for index, (x, y) in enumerate(outline):
            if (index + frame) % (dash + gap) < dash:
                image.set(frame * w + x, y, front if y + 0.5 > h / 2.0 else back)
    return image


KINDS = {"ring": draw_ring}


def load_recipe(path=DEFAULT_RECIPE):
    try:
        recipe = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise FxError(f"{path}: {error}") from error
    if not isinstance(recipe, dict) or not isinstance(recipe.get("pieces"), list):
        raise FxError(f"{path} has no \"pieces\" list")
    return recipe


def build(recipe, allowed):
    """{name: image} for every piece of the recipe; refuses it whole if any colour is off the palette."""
    check_palette(recipe, allowed)
    images = {}
    for piece in recipe["pieces"]:
        name = need(piece, "name")
        if not isinstance(name, str) or not NAME.match(name):
            raise FxError(f"piece name {name!r} is not lower-case letters, digits and _")
        if name in images:
            raise FxError(f"piece {name!r} is made twice")
        kind = need(piece, "kind")
        if kind not in KINDS:
            raise FxError(f"piece {name!r}: kind {kind!r} is not one of {sorted(KINDS)}")
        folder = need(piece, "folder")
        if folder not in FOLDERS:
            raise FxError(f"piece {name!r}: folder {folder!r} is not one of {list(FOLDERS)}")
        images[f"{folder}/{name}"] = KINDS[kind](piece)
    return images


def write_all(images, out):
    out = pathlib.Path(out)
    for name, image in images.items():
        path = out / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        png.write_png(path, image)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    args = parser.parse_args(argv)
    try:
        images = build(load_recipe(args.recipe), palette.load_palette(args.palette))
    except (FxError, png.PngError, OSError) as error:
        print(f"fx.py: {error}", file=sys.stderr)
        return 1
    write_all(images, args.out)
    print(f"fx.py: wrote {len(images)} pieces to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
