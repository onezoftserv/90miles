"""Palette helpers shared by the art tools: the master palette, the outline set and the key ramp,
read from the tracked files (game/assets/art/palette/ and game/resources/art_tuning.tres), and
nearest-colour matching.
"""
import pathlib
import re

import png

REPO = pathlib.Path(__file__).resolve().parents[2]
GAME = REPO / "game"
DEFAULT_PACKS = GAME / "assets"
ART = GAME / "assets" / "art"
MASTER_PALETTE = ART / "palette" / "master_palette.png"
PLAYER_RAMPS = ART / "palette" / "player_ramps.png"
TUNING = GAME / "resources" / "art_tuning.tres"
## The fix overlays' erase colour (design.md C1): never a palette colour.
ERASE = (0xFF, 0x00, 0xFF)


def load_palette(path=MASTER_PALETTE):
    """The master palette's colours, in file order."""
    image = png.read_png(path)
    seen = []
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.get(x, y)
            if pixel[3] and pixel[:3] not in seen:
                seen.append(pixel[:3])
    return seen


def key_ramp(path=PLAYER_RAMPS):
    """Row 0 of player_ramps.png: the clothing key ramp, highlight to line."""
    image = png.read_png(path)
    return [image.get(x, 0)[:3] for x in range(image.width)]


def outline_set(path=TUNING):
    """ArtTuning.outline_colors, parsed from art_tuning.tres."""
    text = pathlib.Path(path).read_text(encoding="utf-8")
    found = re.search(r"^outline_colors = PackedColorArray\(([^)]*)\)", text, re.MULTILINE)
    if not found:
        raise ValueError(f"no outline_colors in {path}")
    values = [float(v) for v in found.group(1).split(",") if v.strip()]
    return [tuple(round(c * 255) for c in values[i:i + 3]) for i in range(0, len(values), 4)]


def distance(a, b):
    """Weighted ("redmean") squared RGB distance."""
    mean = (a[0] + b[0]) / 2
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return (2 + mean / 256) * dr * dr + 4 * dg * dg + (2 + (255 - mean) / 256) * db * db


def nearest(colour, colours):
    """The colour of `colours` nearest `colour` (the first on a tie)."""
    return min(colours, key=lambda candidate: distance(colour[:3], candidate))


def luminance(rgb):
    def linear(channel):
        c = channel / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * linear(rgb[0]) + 0.7152 * linear(rgb[1]) + 0.0722 * linear(rgb[2])


def darkest(colours):
    return min(colours, key=luminance)
