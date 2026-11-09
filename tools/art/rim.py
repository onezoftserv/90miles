"""Give a piece its closed 1 px outline (design.md D8 as amended by C1; DCSS add_rim adapted).

By default the piece's own edge ring is recoloured: each opaque pixel with a transparent
4-neighbour (or one outside its cell) becomes the nearest outline colour, or the one --outline
colour, so the piece keeps its size. With --over <body sheet>, an overlay's edge pixel is
recoloured only where one of its open sides is open in the body's mask too; one whose open sides
the body covers keeps its colour. With --grow, a piece that has no ring of its own (a rough
hand-made icon) gets a 1 px ring grown into the transparent pixels round it, only where an opaque
pixel that is not already an outline colour touches them; an edge still left open at the cell
border is then recoloured.

Usage: python -I tools/art/rim.py <in.png> <out.png> [--cell N] [--outline #rrggbb] [--over body.png]
       [--grow] [--packs <dir>]
"""
import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import palette  # noqa: E402
import png  # noqa: E402

NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def _cells(image, cell):
    width, height = (cell, cell) if isinstance(cell, int) else (cell or (image.width, image.height))
    for top in range(0, image.height - height + 1, height):
        for left in range(0, image.width - width + 1, width):
            yield left, top, width, height


def _open_sides(image, box, x, y):
    left, top, width, height = box
    sides = []
    for dx, dy in NEIGHBOURS:
        nx, ny = x + dx, y + dy
        if not (left <= nx < left + width and top <= ny < top + height) or image.alpha(nx, ny) == 0:
            sides.append((nx, ny))
    return sides


def _inside(box, x, y):
    left, top, width, height = box
    return left <= x < left + width and top <= y < top + height


def rim(image, outline_colours, cell=None, over=None, outline=None, grow=False):
    """The rimmed piece, as a new image; `image` is not changed.

    `cell` is an int (square cells), a (width, height) pair or None (the whole image); `over` is
    the body sheet an overlay is drawn on; `outline` forces one outline colour.
    """
    outline_set = [tuple(c[:3]) for c in outline_colours]
    forced = tuple(outline[:3]) if outline is not None else None
    out = image.copy()
    for box in _cells(image, cell):
        if grow:
            _grow(image, out, box, outline_set, forced)
        _recolour(out, box, outline_set, forced, over)
    return out


def _grow(source, out, box, outline_set, forced):
    colour = forced or outline_set[0]
    left, top, width, height = box
    for y in range(top, top + height):
        for x in range(left, left + width):
            if source.alpha(x, y):
                continue
            for dx, dy in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if _inside(box, nx, ny) and source.alpha(nx, ny) and source.get(nx, ny)[:3] not in outline_set:
                    out.set(x, y, colour + (255,))
                    break


def _recolour(out, box, outline_set, forced, over):
    snapshot = out.copy()
    left, top, width, height = box
    for y in range(top, top + height):
        for x in range(left, left + width):
            pixel = snapshot.get(x, y)
            if pixel[3] == 0:
                continue
            sides = _open_sides(snapshot, box, x, y)
            if not sides:
                continue
            if over is not None and all(_inside(box, nx, ny) and over.alpha(nx, ny) for nx, ny in sides):
                continue
            colour = forced or palette.nearest(pixel, outline_set)
            out.set(x, y, colour + (255,))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--cell", type=int, default=None, help="square frame cell size (default: the whole image)")
    parser.add_argument("--outline", default=None, help="rim in this one outline colour, e.g. #000000")
    parser.add_argument("--over", default=None, help="the body sheet an overlay is drawn on")
    parser.add_argument("--grow", action="store_true", help="grow a 1 px ring round a piece with none")
    parser.add_argument("--tuning", default=str(palette.TUNING), help="art_tuning.tres holding the outline set")
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the packs root (relative paths are tried there too)")
    args = parser.parse_args(argv)
    outline_colours = palette.outline_set(args.tuning)
    forced = png.parse_colour(args.outline) if args.outline else None
    if forced is not None and forced not in outline_colours:
        parser.error(f"{args.outline} is not in the outline set")
    source = png.read_png(_resolve(args.source, args.packs))
    over = png.read_png(_resolve(args.over, args.packs)) if args.over else None
    if over is not None and (over.width, over.height) != (source.width, source.height):
        parser.error("--over must be the same size as the piece")
    result = rim(source, outline_colours, cell=args.cell, over=over, outline=forced, grow=args.grow)
    changed = sum(1 for i in range(0, len(result.pixels), 4) if result.pixels[i:i + 4] != source.pixels[i:i + 4])
    png.write_png(args.target, result)
    print(f"rim: {args.source} -> {args.target}: {changed} pixel(s) changed")
    return 0


def _resolve(path, packs):
    candidate = pathlib.Path(path)
    if candidate.exists() or candidate.is_absolute():
        return candidate
    return pathlib.Path(packs) / candidate


if __name__ == "__main__":
    sys.exit(main())
