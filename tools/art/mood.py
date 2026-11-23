"""Build the squall and open-sea art from hand sources (openspec change art-mood-pass D9).

From the recipe tools/art/mood_fx.json it reads each piece's hand-drawn source in
tools/art/fixes/mood/, checks it, and writes it unchanged to <--out>/<its "to">, --out being the art
root (game/assets/art). It reads no pack: the packs stay read-only. A source is checked for:
- master palette colours and whole alpha (every pixel opaque or clear);
- its size: "frames" frames of "frame" [w, h] side by side;
- "colours": the only colours its opaque pixels may hold;
- "cover": per frame, the most of its pixels that may be opaque (the rain's light and heavy stages);
- "seamless": its frames tile, so a streak running down and to the left that leaves a frame's edge
  goes on at the opposite edge;
- "outline": every opaque pixel beside a clear one or the image's edge holds that colour, a closed
  1 px outline.
If any source is refused, nothing is written and the exit code is non-zero. Two runs give the same
files byte for byte.

Usage: python -I tools/art/mood.py [--recipe tools/art/mood_fx.json] [--fixes tools/art/fixes/mood]
       [--out game/assets/art] [--palette game/assets/art/palette/master_palette.png]
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
DEFAULT_RECIPE = HERE / "mood_fx.json"
DEFAULT_FIXES = HERE / "fixes" / "mood"
DEFAULT_OUT = palette.ART
FOLDERS = ("fx", "sea")
NAME = re.compile(r"^[a-z][a-z0-9_]*\.png$")
# A rain streak runs down and to the left, one pixel a row.
STREAK = (-1, 1)


class MoodError(ValueError):
    """A recipe or a source the builder refuses."""


def load_recipe(path=DEFAULT_RECIPE):
    try:
        recipe = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise MoodError(f"{path}: {error}") from error
    if not isinstance(recipe, dict) or not isinstance(recipe.get("pieces"), list):
        raise MoodError(f"{path} has no \"pieces\" list")
    return recipe


def _need(piece, key):
    if key not in piece:
        raise MoodError(f"piece {piece.get('source', '?')!r} has no \"{key}\"")
    return piece[key]


def _colour(text, where):
    try:
        return png.parse_colour(text)
    except (AttributeError, ValueError) as error:
        raise MoodError(f"{where}: {text!r} is not a #rrggbb colour") from error


def _frames(image, piece):
    width, height = _need(piece, "frame")
    count = _need(piece, "frames")
    if (image.width, image.height) != (width * count, height):
        raise MoodError(f"{piece['source']}: {image.width}x{image.height}, not {count} frames of {width}x{height}")
    return [image.crop(i * width, 0, width, height) for i in range(count)]


def check(image, piece, allowed):
    """Raises MoodError naming the first rule `image` breaks; returns it unchanged."""
    name = piece["source"]
    on_palette = {tuple(c[:3]) for c in allowed}
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.get(x, y)
            if a not in (0, 255):
                raise MoodError(f"{name}: ({x}, {y}) is half transparent (alpha {a})")
            if a and (r, g, b) not in on_palette:
                raise MoodError(f"{name}: ({x}, {y}) {png.colour_hex((r, g, b))} is not in the master palette")
    frames = _frames(image, piece)
    if "colours" in piece:
        only = {_colour(c, name) for c in piece["colours"]}
        for y in range(image.height):
            for x in range(image.width):
                pixel = image.get(x, y)
                if pixel[3] and pixel[:3] not in only:
                    raise MoodError(f"{name}: ({x}, {y}) {png.colour_hex(pixel[:3])} is not one of its colours {sorted(piece['colours'])}")
    for index, limit in enumerate(piece.get("cover", [])):
        frame = frames[index]
        share = sum(1 for alpha in frame.pixels[3::4] if alpha) / (frame.width * frame.height)
        if share > limit:
            raise MoodError(f"{name}: frame {index} covers {share:.0%}, more than {limit:.0%}")
    if piece.get("seamless"):
        for index, frame in enumerate(frames):
            _check_seamless(frame, f"{name} frame {index}")
    if "outline" in piece:
        line = _colour(piece["outline"], name)
        for y in range(image.height):
            for x in range(image.width):
                if not image.alpha(x, y):
                    continue
                edge = any(not (0 <= x + dx < image.width and 0 <= y + dy < image.height) or not image.alpha(x + dx, y + dy)
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge and image.get(x, y)[:3] != line:
                    raise MoodError(f"{name}: ({x}, {y}) is on the outline but not {piece['outline']}")
    return image


def _check_seamless(frame, where):
    """A streak pixel on a frame's edge whose next or last pixel along the streak falls outside the
    frame goes on at the opposite edge, so the frame tiles with no cut streaks."""
    width, height = frame.width, frame.height
    for y in range(height):
        for x in range(width):
            if not frame.alpha(x, y):
                continue
            for sign in (1, -1):
                nx, ny = x + sign * STREAK[0], y + sign * STREAK[1]
                if 0 <= nx < width and 0 <= ny < height:
                    continue
                if not frame.alpha(nx % width, ny % height):
                    raise MoodError(f"{where}: the streak at ({x}, {y}) is cut at the edge, so the tile shows a seam")


def build(recipe, fixes, allowed):
    """{target: image} for every piece; refuses the whole recipe on any bad source."""
    images = {}
    for piece in recipe["pieces"]:
        source = _need(piece, "source")
        if not isinstance(source, str) or not NAME.match(source):
            raise MoodError(f"source {source!r} is not a lower-case .png name")
        target = _need(piece, "to")
        folder = str(target).split("/")[0]
        if folder not in FOLDERS or not NAME.match(str(target).split("/", 1)[-1]):
            raise MoodError(f"{source}: target {target!r} is not fx/<name>.png or sea/<name>.png")
        if target in images:
            raise MoodError(f"{target} is made twice")
        path = pathlib.Path(fixes) / source
        if not path.is_file():
            raise MoodError(f"{source}: no such hand-drawn source in {fixes}")
        images[target] = check(png.read_png(path), piece, allowed)
    return images


def write_all(images, out):
    out = pathlib.Path(out)
    for target, image in images.items():
        path = out / target
        path.parent.mkdir(parents=True, exist_ok=True)
        png.write_png(path, image)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    args = parser.parse_args(argv)
    try:
        images = build(load_recipe(args.recipe), args.fixes, palette.load_palette(args.palette))
    except (MoodError, png.PngError, OSError) as error:
        print(f"mood.py: {error}", file=sys.stderr)
        return 1
    write_all(images, args.out)
    print(f"mood.py: wrote {len(images)} pieces to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
