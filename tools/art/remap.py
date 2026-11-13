"""Remap a piece to the master palette or to a per-part colour map (design.md D7, D8, C1 D7).

Each opaque pixel takes its colour map entry if it has one, keeps a colour already in the
palette, and otherwise takes the nearest palette colour, never a clothing key colour (only a
colour map writes those). With --strict, an unmapped colour outside the palette is an error
instead (body parts map every colour explicitly). Half-transparent pixels are dropped, except in
a target under shadows/ or decals/, where they keep their alpha in the palette's darkest colour.
Every change is printed.

Usage: python -I tools/art/remap.py <in.png> <out.png> [--map map.json] [--strict]
       [--palette master_palette.png] [--packs <dir>]
"""
import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import guard  # noqa: E402
import palette  # noqa: E402
import png  # noqa: E402

PARTIAL_ALPHA_DIRS = ("shadows", "decals")


class RemapError(ValueError):
    """An unmapped colour outside the palette in strict mode."""


def parse_map(entries):
    """{"#rrggbb": "#rrggbb"} to {(r, g, b): (r, g, b)}."""
    return {png.parse_colour(source): png.parse_colour(target) for source, target in entries.items()}


def remap(image, palette_colours, colour_map=None, keep_partial_alpha=False, exclude=(), strict=False):
    """The remapped piece and its changes {(from hex, to hex): count}; `image` is not changed."""
    colours = [tuple(c[:3]) for c in palette_colours]
    in_palette = set(colours)
    targets = [c for c in colours if c not in {tuple(e[:3]) for e in exclude}]
    mapping = dict(colour_map or {})
    shadow = palette.darkest(colours)
    out = image.copy()
    changes = {}
    unmapped = set()
    for i in range(0, len(out.pixels), 4):
        alpha = out.pixels[i + 3]
        if alpha == 0:
            out.pixels[i:i + 4] = b"\x00\x00\x00\x00"
            continue
        rgb = tuple(out.pixels[i:i + 3])
        if alpha < 255:
            if keep_partial_alpha:
                target = shadow
            else:
                out.pixels[i:i + 4] = b"\x00\x00\x00\x00"
                key = (png.colour_hex(rgb) + f"@{alpha}", "transparent")
                changes[key] = changes.get(key, 0) + 1
                continue
        elif rgb in mapping:
            target = mapping[rgb]
        elif rgb in in_palette:
            target = rgb
        elif strict:
            unmapped.add(rgb)
            continue
        else:
            target = palette.nearest(rgb, targets)
        if target != rgb:
            key = (png.colour_hex(rgb), png.colour_hex(target))
            changes[key] = changes.get(key, 0) + 1
            out.pixels[i:i + 3] = bytes(target)
    if unmapped:
        names = ", ".join(sorted(png.colour_hex(c) for c in unmapped))
        raise RemapError(f"colours with no colour map entry and not in the palette: {names}")
    return out, changes


def report(name, changes, log=print):
    for (source, target), count in sorted(changes.items()):
        log(f"  {name}: {source} -> {target} ({count} px)")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--map", default=None, help="a JSON file of {\"#rrggbb\": \"#rrggbb\"}")
    parser.add_argument("--strict", action="store_true", help="fail on an unmapped colour outside the palette")
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the packs root (relative paths are tried there too)")
    args = parser.parse_args(argv)
    source_path = pathlib.Path(args.source)
    if not source_path.exists() and not source_path.is_absolute():
        source_path = pathlib.Path(args.packs) / source_path
    colour_map = parse_map(json.loads(pathlib.Path(args.map).read_text(encoding="utf-8"))) if args.map else None
    target = pathlib.Path(args.target)
    try:
        guard.out_folder(target, args.packs, RemapError)
    except RemapError as error:
        print(f"remap: {error}", file=sys.stderr)
        return 1
    keep = any(part in PARTIAL_ALPHA_DIRS for part in target.resolve().parent.parts)
    try:
        out, changes = remap(png.read_png(source_path), palette.load_palette(args.palette), colour_map, keep, palette.key_ramp(), args.strict)
    except png.PngError as error:
        print(f"remap: {args.source} is not a readable PNG: {error}", file=sys.stderr)
        return 1
    except RemapError as error:
        print(f"remap: {args.source}: {error}", file=sys.stderr)
        return 1
    png.write_png(target, out)
    print(f"remap: {args.source} -> {args.target}: {sum(changes.values())} pixel(s) changed")
    report(target.name, changes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
