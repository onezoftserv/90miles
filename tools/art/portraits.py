"""Build the speaker portraits (art-guardacostas D10).

From the recipe tools/art/portraits.json and the hand-drawn sources of --fixes it makes
game/assets/art/portraits/<id>.png, one bust per speaker, drawn by the scene panel in a 36x36
window_dark frame. A portrait is {"id", "hand", "size", "outline"}, all four required:

- "id": lower-case letters, digits and _, the name of the PNG it makes.
- "hand": a hand-drawn source of the fixes folder (a bare <name>.png), the portrait's own "size",
  already in the master palette and whole alpha (each pixel fully opaque or fully transparent).
- "outline": one colour of the outline set. The portrait's edge ring (each opaque pixel with a
  transparent 4-neighbour, or on the image border) is recoloured to it (rim.py), so the piece
  keeps its size. A portrait is an actor's face, so the shipped ones are rimmed "#000000".

Every portrait must then pass the palette, whole-alpha and outline rules (creatures.py's check).
Nothing is written inside a download folder, and nothing at all when a portrait is refused. Run
again on the same sources it gives the same PNGs byte for byte.

Usage: python -I tools/art/portraits.py [--recipe tools/art/portraits.json]
       [--fixes tools/art/fixes/portraits] [--out game/assets/art]
"""
import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import creatures  # noqa: E402
import guard  # noqa: E402
import palette  # noqa: E402
import png  # noqa: E402
import rim  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_RECIPE = HERE / "portraits.json"
DEFAULT_FIXES = HERE / "fixes" / "portraits"
DEFAULT_OUT = palette.ART
FOLDER = "portraits"
KEYS = ("id", "hand", "size", "outline")
NAME = re.compile(r"^[a-z0-9_]+$")
HAND = re.compile(r"^[a-z0-9_]+\.png$")


class PortraitArtError(ValueError):
    """A recipe, source or portrait the builder refuses."""


def load_recipe(path=DEFAULT_RECIPE):
    try:
        recipe = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise PortraitArtError(f"{path}: {error}") from error
    if not isinstance(recipe, dict) or not isinstance(recipe.get("portraits"), list):
        raise PortraitArtError(f"{path} has no \"portraits\" list")
    return recipe


def palette_problem(image, name, allowed):
    """Raises on the first pixel that is half transparent or off the palette."""
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if not pixel[3]:
                continue
            if pixel[3] < 255:
                raise PortraitArtError(f"{name}: a half-transparent pixel at ({x}, {y})")
            if pixel[:3] not in allowed:
                raise PortraitArtError(f"{name}: {png.colour_hex(pixel[:3])} at ({x}, {y}) is not in the master palette")


def build_portrait(entry, fixes, allowed, outline):
    """The portrait's path under the art folder and its rimmed, checked image."""
    try:
        return _portrait(entry, fixes, allowed, outline)
    except (creatures.CreatureArtError, png.PngError) as error:
        raise PortraitArtError(str(error)) from error


def _portrait(entry, fixes, allowed, outline):
    if not isinstance(entry, dict):
        raise PortraitArtError(f"the portrait {entry!r} is not an object")
    portrait_id = str(creatures.need(entry, "id", "a portrait"))
    if not NAME.match(portrait_id):
        raise PortraitArtError(f"portrait id {portrait_id!r} is not lower-case letters, digits and _")
    for key in KEYS:
        creatures.need(entry, key, portrait_id)
    unknown = sorted(set(entry) - set(KEYS))
    if unknown:
        raise PortraitArtError(f"{portrait_id}: unknown key(s) {', '.join(unknown)}")
    size = creatures.pair(entry["size"], f"{portrait_id} size")
    if 0 in size:
        raise PortraitArtError(f"{portrait_id}: the size {size} is empty")
    hand = str(entry["hand"])
    if not HAND.match(hand):
        raise PortraitArtError(f"{portrait_id}: {hand!r} is not a bare <name>.png in lower-case letters, digits and _")
    forced = creatures.colour(entry["outline"], portrait_id)
    if forced not in outline:
        raise PortraitArtError(f"{portrait_id}: its outline {png.colour_hex(forced)} is not an outline colour")
    source = creatures.hand_layer({"hand": hand}, fixes, size, portrait_id)
    palette_problem(source, f"{portrait_id} ({hand})", allowed)
    if source.is_empty():
        raise PortraitArtError(f"{portrait_id}: {hand} is empty")
    rimmed = rim.rim(source, [forced], outline=forced)
    return f"{FOLDER}/{portrait_id}.png", creatures.checked(rimmed, portrait_id, allowed, {forced}, tuple(size))


def build(recipe, fixes, out, palette_colours, outline_colours, packs=palette.DEFAULT_PACKS, log=print):
    """Builds every portrait of the recipe, checks them all, then writes them under `out`."""
    out = guard.out_folder(out, packs, PortraitArtError)
    if not isinstance(recipe, dict) or not isinstance(recipe.get("portraits"), list):
        raise PortraitArtError("the recipe has no \"portraits\" list")
    allowed = {tuple(c[:3]) for c in palette_colours}
    outline = {tuple(c[:3]) for c in outline_colours}
    portraits = {}
    for entry in recipe["portraits"]:
        name, image = build_portrait(entry, fixes, allowed, outline)
        if name in portraits:
            raise PortraitArtError(f"{name} is made twice")
        portraits[name] = image
    for name, image in portraits.items():
        (out / name).parent.mkdir(parents=True, exist_ok=True)
        png.write_png(out / name, image)
        log(f"portraits: {name} ({image.width}x{image.height})")
    return portraits


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    parser.add_argument("--tuning", default=str(palette.TUNING), help="art_tuning.tres, for the outline set")
    args = parser.parse_args(argv)
    try:
        build(load_recipe(args.recipe), args.fixes, args.out, palette.load_palette(args.palette), palette.outline_set(args.tuning))
    except (PortraitArtError, png.PngError) as error:
        print(f"portraits: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
