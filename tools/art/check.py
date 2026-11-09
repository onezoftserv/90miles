"""Quick local art checks (design.md D8, D9, D21, K11): the licence rule, palette, alpha, outline and
lossless import, over a folder of PNGs. The GUT tests (test_art_tracked.gd, test_art_checks.gd)
are the gate, because CI has no packs; this mirrors their file rules for a run before committing.

Rules by folder, relative to the root:
- licence: every folder holding a PNG has a License.txt whose blocks each start with "Pack:" or
  "Work:" (vendor text above the first is not checked) and have a licence line and their own
  Source: line; a pack's source is its page, never a licence deed, and an own-work block's source
  is "90 Millas (own work)". Inside a Godot project every PNG must be named by a .tscn or .tres.
- palette and alpha: every PNG but those under ui/ (and EXEMPT) uses only master palette colours,
  fully opaque or fully transparent, except under shadows/ and decals/ (the darkest colour).
- outline: every edge pixel under creatures/, items/ (16x16 cells) and structures/ is an outline
  colour.
- import: inside a Godot project each PNG's .import is lossless (compress/mode=0), no mipmaps.
A folder under tools/ (tools/art/fixes/, pipeline source never drawn) gets the licence rule only.

Usage: python -I tools/art/check.py <folder> [--licence-only] [--packs <dir>]
"""
import argparse
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import palette  # noqa: E402
import png  # noqa: E402

OWN_WORK_SOURCE = "90 Millas (own work)"
LICENCE_FILE = "License.txt"
LICENCE_HOSTS = ("creativecommons.org", "opensource.org", "gnu.org", "spdx.org", "opendatacommons.org")
PARTIAL_ALPHA_DIRS = ("shadows", "decals")
OUTLINE_DIRS = ("creatures", "items", "structures")
ITEM_CELL = 16
PALETTE_EXEMPT_DIRS = ("ui",)
## Temporary, relative to game/assets/art: the Kenney placeholder predates the master palette.
## Task 5.7 deletes it and empties this list (and the one in test_art_tracked.gd).
EXEMPT = ("characters/player_placeholder.png",)
REFERRER_SKIPPED = ("tests", ".godot", "addons", "assets/kenney", "assets/oga", "assets/itch", "assets/audio/ambience")
KEY_LINE = re.compile(r"^([A-Z][A-Za-z]*):(?:\s+(.*))?$")
MAX_LISTED = 3


def licence_blocks(text):
    """The blocks of a License.txt, each a dict of its own "Key: value" lines."""
    blocks = []
    current = None
    for raw in text.splitlines():
        found = KEY_LINE.match(raw.rstrip())
        if not found:
            continue
        key, value = found.group(1), (found.group(2) or "").strip()
        if key in ("Pack", "Work"):
            current = {"kind": key}
            blocks.append(current)
        if current is not None and key not in current:
            current[key] = value
    return blocks


def licence_problems(folder, text):
    blocks = licence_blocks(text)
    if not blocks:
        return [f"{folder}/{LICENCE_FILE} has no block starting with a Pack: or Work: line"]
    problems = []
    for block in blocks:
        problem = _block_problem(block)
        if problem:
            problems.append(f"{folder}/{LICENCE_FILE}: {block['kind']} '{block[block['kind']]}' {problem}")
    return problems


def _block_problem(block):
    if not (block.get("Licence") or block.get("License")):
        return "has no Licence: line"
    source = block.get("Source", "")
    if not source:
        return "has no Source: line of its own"
    if block["kind"] == "Work":
        return "" if source == OWN_WORK_SOURCE else f"gives '{source}' as its source, not {OWN_WORK_SOURCE}"
    if not block.get("Author"):
        return "has no Author: line"
    if not source.startswith(("https://", "http://")):
        return f"gives '{source}' as its source, not the pack's page"
    host = source.split("://", 1)[1].split("/", 1)[0].lower()
    if any(host == h or host.endswith("." + h) for h in LICENCE_HOSTS):
        return f"gives the licence deed {source} as its source, not the pack's page"
    return ""


def is_licence_only(root):
    return pathlib.Path(root).resolve().is_relative_to(palette.REPO / "tools")


def _godot_project(root):
    for folder in [pathlib.Path(root).resolve(), *pathlib.Path(root).resolve().parents]:
        if (folder / "project.godot").is_file():
            return folder
    return None


def _res_path(path, game):
    return "res://" + path.resolve().relative_to(game).as_posix()


def _referrer_text(root, game):
    """The text of every scene and resource that may refer to a PNG under `root`."""
    tests = game / "tests"
    if pathlib.Path(root).resolve().is_relative_to(tests):
        scope, skipped = [pathlib.Path(root).resolve()], ()
    else:
        scope, skipped = [game], tuple(game / s for s in REFERRER_SKIPPED)
    texts = []
    for folder in scope:
        for path in folder.rglob("*"):
            if path.suffix in (".tscn", ".tres") and not any(path.is_relative_to(s) for s in skipped):
                texts.append(path.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(texts)


def _listed(path, rule, offenders):
    if not offenders:
        return []
    return [f"{path}: {len(offenders)} {rule}: {', '.join(offenders[:MAX_LISTED])}"]


def palette_problems(path, image, colours, partial_ok):
    known = set(colours)
    shadow = palette.darkest(colours)
    off, partial = [], []
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.get(x, y)
            if a == 0:
                continue
            if (r, g, b) not in known:
                off.append(f"({x}, {y}) {png.colour_hex((r, g, b))}")
            if a < 255 and not (partial_ok and (r, g, b) == shadow):
                partial.append(f"({x}, {y}) alpha {a} {png.colour_hex((r, g, b))}")
    rule = f"partly transparent pixel(s) not in the darkest colour {png.colour_hex(shadow)}" if partial_ok else "partly transparent pixel(s) outside shadows/ and decals/"
    return _listed(path, "pixel(s) not in the master palette", off) + _listed(path, rule, partial)


def outline_problems(path, image, outline_colours, cell):
    outline = set(outline_colours)
    width, height = cell
    offenders = []
    for top in range(0, image.height - height + 1, height):
        for left in range(0, image.width - width + 1, width):
            for y in range(top, top + height):
                for x in range(left, left + width):
                    pixel = image.get(x, y)
                    if pixel[3] == 0 or pixel[:3] in outline:
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if not (left <= nx < left + width and top <= ny < top + height) or image.alpha(nx, ny) == 0:
                            offenders.append(f"cell ({left // width}, {top // height}) pixel ({x}, {y}) {png.colour_hex(pixel)}")
                            break
    return _listed(path, "edge pixel(s) not in the outline set", offenders)


def import_params(text):
    """The key=value lines of an .import file's [params] section (its [remap] section holds
    multi-line values that INI readers refuse, so the file is read line by line)."""
    params, section = {}, None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
        elif section == "params" and "=" in stripped:
            key, value = stripped.split("=", 1)
            params[key.strip()] = value.strip()
    return params


def import_problems(path, shown):
    try:
        params = import_params(path.with_name(path.name + ".import").read_text(encoding="utf-8"))
    except OSError:
        return [f"{shown} has no readable .import"]
    problems = []
    if params.get("compress/mode") != "0":
        problems.append(f"{shown} imports with compress/mode={params.get('compress/mode', '?')}, not 0 (lossless)")
    if params.get("mipmaps/generate") != "false":
        problems.append(f"{shown} imports with mipmaps/generate={params.get('mipmaps/generate', '?')}, not false")
    return problems


def check_tree(root, palette_colours=None, outline_colours=None, licence_only=None):
    """Every problem under `root`, one line each, naming the file or folder."""
    root = pathlib.Path(root).resolve()
    licence_only = is_licence_only(root) if licence_only is None else licence_only
    pngs = sorted(root.rglob("*.png"))
    problems = []
    for folder in sorted({p.parent for p in pngs}):
        licence = folder / LICENCE_FILE
        if not licence.is_file():
            problems.append(f"{_shown(folder, root)} holds a PNG and has no {LICENCE_FILE}")
        else:
            problems.extend(licence_problems(_shown(folder, root), licence.read_text(encoding="utf-8", errors="replace")))
    if licence_only:
        return problems
    colours = palette_colours or palette.load_palette()
    outline = outline_colours or palette.outline_set()
    game = _godot_project(root)
    referrers = _referrer_text(root, game) if game else None
    art = palette.ART.resolve()
    for path in pngs:
        shown = _shown(path, root)
        # Folder rules read from game/assets/art when the root lies inside it, so a run on one of
        # its subfolders applies the same rules; from the root itself elsewhere (the fixtures).
        relative = path.relative_to(art if root.is_relative_to(art) else root)
        if game:
            problems.extend(import_problems(path, shown))
            if f'"{_res_path(path, game)}"' not in referrers:
                problems.append(f"{shown} is referred to by no scene or resource")
        try:
            image = png.read_png(path)
        except png.PngError as error:
            problems.append(f"{shown} is not a readable PNG: {error}")
            continue
        exempt = relative.parts[0] in PALETTE_EXEMPT_DIRS or (root.is_relative_to(art) and relative.as_posix() in EXEMPT)
        if not exempt:
            partial_ok = any(part in PARTIAL_ALPHA_DIRS for part in relative.parts[:-1])
            problems.extend(palette_problems(shown, image, colours, partial_ok))
        if relative.parts[0] in OUTLINE_DIRS:
            cell = (ITEM_CELL, ITEM_CELL) if relative.parts[0] == "items" else (image.width, image.height)
            problems.extend(outline_problems(shown, image, outline, cell))
    return problems


def _shown(path, root):
    """A path relative to the repository when inside it, with forward slashes."""
    try:
        return path.relative_to(palette.REPO).as_posix()
    except ValueError:
        return path.as_posix()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root")
    parser.add_argument("--licence-only", action="store_true", help="check only the licence rule (as for tools/art/fixes/)")
    parser.add_argument("--packs", default=str(palette.DEFAULT_PACKS), help="accepted for symmetry; the checks read only the folder given")
    args = parser.parse_args(argv)
    root = pathlib.Path(args.root)
    if not root.is_dir():
        parser.error(f"{root} is not a folder")
    problems = check_tree(root, licence_only=True if args.licence_only else None)
    for problem in problems:
        print(problem)
    print(f"check: {_shown(root.resolve(), root)}: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
