"""Build the player part sheets (design.md C1, D4 as replaced by layered parts).

For each part in tools/art/look_parts.json: cut the 18 walk frames of its band from its pack
file, apply the pose rules of poses.py, blend the hand-fix overlay tools/art/fixes/<id>.png last
(an opaque pixel replaces, #ff00ff erases), remap (the part's colour map, then the master
palette), and then rim in the part's outline colour, --over its body sheet for an overlay (the
rules change which pixels touch transparency, so the rim comes after them). Writes
game/assets/art/characters/parts/<id>.png. It fails, naming the part and the cell, if a rule would
push an opaque pixel out of its cell or drop one outside the rows it deletes, and when a built
sheet breaks the invariant of poses.invariant_problems.

A part entry: {"id": "hair_0", "file": "itch/metrocity/<...>/Hairs.png" (under --packs),
"band": 0 (the 32 px row), "layer": "body" | "outfit" | "hair" | "item", "outline": "#000000",
optional "colour_map": {"#rrggbb": "#rrggbb"}, "strict": true (every colour outside the palette
must be mapped), "over": "body_man" (the body sheet an overlay is rimmed over, built first)}.

Usage: python -I tools/art/compose.py [part ids] [--packs <dir>] [--parts look_parts.json]
       [--fixes tools/art/fixes] [--out game/assets/art/characters/parts]
"""
import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import palette  # noqa: E402
import png  # noqa: E402
import poses  # noqa: E402
import remap  # noqa: E402
import rim  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_PARTS = HERE / "look_parts.json"
DEFAULT_FIXES = HERE / "fixes"
DEFAULT_OUT = palette.ART / "characters" / "parts"
LAYERS = ("body", "outfit", "hair", "item")
PART_ID = re.compile(r"^[a-z0-9_]+$")


class PartError(ValueError):
    """A part entry that cannot be built as written."""


def load_parts(path=DEFAULT_PARTS):
    data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    parts = data.get("parts")
    if not isinstance(parts, list):
        raise PartError(f"{path} has no \"parts\" list")
    return parts


def fix_pixels(fix):
    """The hand-fixed (column, row, x, y) of an overlay's opaque pixels, exempt from the invariant."""
    exempt = set()
    for y in range(fix.height):
        for x in range(fix.width):
            if fix.alpha(x, y):
                exempt.add((x // poses.CELL, y // poses.CELL, x % poses.CELL, y % poses.CELL))
    return frozenset(exempt)


def apply_fix(sheet, fix):
    """The sheet with the fix overlay blended last: an opaque pixel replaces, #ff00ff erases."""
    if (fix.width, fix.height) != (sheet.width, sheet.height):
        raise PartError(f"the fix overlay is {fix.width}x{fix.height}, not {sheet.width}x{sheet.height}")
    out = sheet.copy()
    for y in range(fix.height):
        for x in range(fix.width):
            pixel = fix.get(x, y)
            if pixel[3] == 0:
                continue
            out.set(x, y, (0, 0, 0, 0) if pixel[:3] == palette.ERASE else pixel[:3] + (255,))
    return out


def _validated(part, packs):
    for key in ("id", "file", "band", "layer", "outline"):
        if key not in part:
            raise PartError(f"part {part.get('id', '?')} has no \"{key}\"")
    part_id = part["id"]
    if not PART_ID.match(str(part_id)):
        raise PartError(f"part id {part_id!r} is not lower-case letters, digits and _")
    if part["layer"] not in LAYERS:
        raise PartError(f"{part_id}: layer {part['layer']!r} is not one of {LAYERS}")
    packs_root = pathlib.Path(packs).resolve()
    source = (packs_root / part["file"]).resolve()
    if not source.is_relative_to(packs_root):
        raise PartError(f"{part_id}: {part['file']} is outside the packs root")
    if not source.is_file():
        raise PartError(f"{part_id}: {source} not found (is --packs the folder holding itch/ and oga/?)")
    if not isinstance(part["band"], int) or part["band"] < 0:
        raise PartError(f"{part_id}: band must be a whole number from 0")
    return part_id, source


def build_part(part, packs, fixes, palette_colours, outline_colours, exclude=(), over=None, log=print):
    """One part's sheet: cut, rules, fix, remap, rim."""
    part_id, source = _validated(part, packs)
    walk = poses.cut_walk_frames(png.read_png(source), part["band"], part_id)
    sheet = poses.build_sheet(walk, part_id)
    fix_path = pathlib.Path(fixes) / f"{part_id}.png"
    exempt = frozenset()
    if fix_path.is_file():
        fix = png.read_png(fix_path)
        sheet = apply_fix(sheet, fix)
        exempt = fix_pixels(fix)
    colour_map = remap.parse_map(part.get("colour_map", {}))
    try:
        sheet, changes = remap.remap(sheet, palette_colours, colour_map, exclude=exclude, strict=bool(part.get("strict", False)))
    except remap.RemapError as error:
        raise PartError(f"{part_id}: {error}") from error
    remap.report(part_id, changes, log)
    outline = png.parse_colour(part["outline"])
    if outline not in [tuple(c[:3]) for c in outline_colours]:
        raise PartError(f"{part_id}: outline {part['outline']} is not in the outline set")
    sheet = rim.rim(sheet, outline_colours, cell=poses.CELL, over=over, outline=outline)
    problems = poses.invariant_problems(sheet, part_id, outline_colours, over=over, exempt=exempt)
    if problems:
        raise PartError("\n".join(problems))
    return sheet


def build_parts(parts, packs, fixes, out, palette_colours, outline_colours, exclude=(), log=print):
    """Builds and writes each part in order; an overlay's body is built before it or read from `out`."""
    out = pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    built = {}
    for part in parts:
        over = None
        if part.get("over"):
            body_id = part["over"]
            if body_id in built:
                over = built[body_id]
            elif PART_ID.match(str(body_id)) and (out / f"{body_id}.png").is_file():
                over = png.read_png(out / f"{body_id}.png")
            else:
                raise PartError(f"{part.get('id', '?')}: its body {body_id} is not built (list it first)")
        sheet = build_part(part, packs, fixes, palette_colours, outline_colours, exclude, over, log)
        png.write_png(out / f"{part['id']}.png", sheet)
        log(f"compose: {part['id']} -> {out / (part['id'] + '.png')}")
        built[part["id"]] = sheet
    return built


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("ids", nargs="*", help="the parts to build (default: all, in file order)")
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="the folder holding itch/ and oga/")
    parser.add_argument("--parts", default=str(DEFAULT_PARTS))
    parser.add_argument("--fixes", default=str(DEFAULT_FIXES))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--palette", default=str(palette.MASTER_PALETTE))
    parser.add_argument("--tuning", default=str(palette.TUNING))
    args = parser.parse_args(argv)
    try:
        parts = load_parts(args.parts)
        if args.ids:
            unknown = set(args.ids) - {p.get("id") for p in parts}
            if unknown:
                raise PartError(f"no such part: {', '.join(sorted(unknown))}")
            parts = [p for p in parts if p.get("id") in args.ids]
        if not parts:
            print("compose: no parts to build")
            return 0
        build_parts(parts, args.packs, args.fixes, args.out, palette.load_palette(args.palette), palette.outline_set(args.tuning), palette.key_ramp())
    except (PartError, poses.PoseError, png.PngError) as error:
        print(f"compose: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
