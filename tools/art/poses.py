"""The frame layout and the pose rules of design.md C1, applied with the same constants to every
layer of a look (body, outfit, hair, item).

The frame layout is a 320x128 sheet of 10x4 cells of 32x32. Rows 0-2 are the down, side (facing
right) and up facings, with walk in columns 0-5 (idle is column 0), crouch in 6-7 and swim in 8-9;
row 3 holds downed in columns 0-1 and dead in column 2. Every rule is a pure pixel remap, so
applying it per layer and compositing equals compositing and applying it.
"""
from dataclasses import dataclass
from typing import Callable

import png

CELL = 32
COLUMNS, ROWS = 10, 4
SHEET_WIDTH, SHEET_HEIGHT = COLUMNS * CELL, ROWS * CELL
FACINGS = ("down", "side", "up")
WALK_FRAMES = 6
## The MetroCity columns of each facing's first walk frame; the left facing (18-23) is a mirror.
SOURCE_COLUMNS = {"down": 0, "side": 6, "up": 12}
CROUCH_FROM, CROUCH_COLUMNS = (0, 1), (6, 7)
SWIM_FROM, SWIM_COLUMNS = (1, 4), (8, 9)
DOWNED_ROW, DOWNED_COLUMNS, DEAD_COLUMN = 3, (0, 1), 2
CROUCH_DELETED_ROWS = frozenset({21, 22, 23, 27, 28, 29})
DOWNED_DROP = 8
CHEST_COLUMNS = range(8, 15)
NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


class PoseError(ValueError):
    """A rule that would push an opaque pixel out of its cell or drop one it does not delete."""


@dataclass(frozen=True)
class Rule:
    """Where each source pixel of a 32x32 cell goes: (x, y), or None for a deleted row."""

    name: str
    mapping: Callable[[int, int], "tuple[int, int] | None"]
    deleted_rows: frozenset = frozenset()


def _crouch(x, y):
    if y in CROUCH_DELETED_ROWS:
        return None
    if y < 21:
        return (x, y + 6)
    if y < 27:
        return (x, y + 3)
    return (x, y)


CROUCH = Rule("crouch", _crouch, CROUCH_DELETED_ROWS)
TURN_DOWN = Rule("downed", lambda x, y: (CELL - 1 - y, x + DOWNED_DROP))
CHEST_LIFT = Rule("chest lift", lambda x, y: (x, y - 1) if x in CHEST_COLUMNS else (x, y))


@dataclass(frozen=True)
class MadeCell:
    """A rule-made cell of the layout and the walk cell it is made from."""

    column: int
    row: int
    source_column: int
    source_row: int
    rules: tuple


def _made_cells():
    cells = []
    for row in range(len(FACINGS)):
        for column, source in zip(CROUCH_COLUMNS, CROUCH_FROM):
            cells.append(MadeCell(column, row, source, row, (CROUCH,)))
        for column, source in zip(SWIM_COLUMNS, SWIM_FROM):
            cells.append(MadeCell(column, row, source, row, ()))
    cells.append(MadeCell(DOWNED_COLUMNS[0], DOWNED_ROW, 0, 0, (TURN_DOWN,)))
    cells.append(MadeCell(DOWNED_COLUMNS[1], DOWNED_ROW, 0, 0, (TURN_DOWN, CHEST_LIFT)))
    cells.append(MadeCell(DEAD_COLUMN, DOWNED_ROW, 0, 0, (TURN_DOWN,)))
    return tuple(cells)


MADE_CELLS = _made_cells()


def cell_rect(column, row):
    return (column * CELL, row * CELL, CELL, CELL)


def cell(sheet, column, row):
    x, y, w, h = cell_rect(column, row)
    return sheet.crop(x, y, w, h)


def apply_rule(rule, frame, part, at):
    """`rule` applied to a 32x32 frame; raises PoseError naming `part` and the cell `at`."""
    out = png.blank(CELL, CELL)
    for y in range(CELL):
        for x in range(CELL):
            pixel = frame.get(x, y)
            if pixel[3] == 0:
                continue
            target = rule.mapping(x, y)
            if target is None:
                if y in rule.deleted_rows:
                    continue
                raise PoseError(f"{part}: the {rule.name} rule drops the opaque pixel ({x}, {y}) outside the rows it deletes, in cell {at}")
            tx, ty = target
            if not (0 <= tx < CELL and 0 <= ty < CELL):
                raise PoseError(f"{part}: the {rule.name} rule pushes the opaque pixel ({x}, {y}) out of cell {at}, to ({tx}, {ty})")
            if out.get(tx, ty)[3] != 0:
                raise PoseError(f"{part}: the {rule.name} rule drops an opaque pixel under ({tx}, {ty}) in cell {at}")
            out.set(tx, ty, pixel)
    return out


def apply_rules(rules, frame, part, at):
    for rule in rules:
        frame = apply_rule(rule, frame, part, at)
    return frame


def cut_walk_frames(source, band, part):
    """The 18 walk frames (down, side, up) of a MetroCity band: row `band` of 32x32 cells."""
    needed = (max(SOURCE_COLUMNS.values()) + WALK_FRAMES) * CELL
    if source.width < needed or source.height < (band + 1) * CELL:
        raise PoseError(f"{part}: band {band} is outside the {source.width}x{source.height} source")
    return {facing: [source.crop((SOURCE_COLUMNS[facing] + i) * CELL, band * CELL, CELL, CELL) for i in range(WALK_FRAMES)] for facing in FACINGS}


def build_sheet(walk, part):
    """The frame layout from six walk frames per facing, every pose made by its rule."""
    sheet = png.blank(SHEET_WIDTH, SHEET_HEIGHT)
    for row, facing in enumerate(FACINGS):
        for index in range(WALK_FRAMES):
            sheet.paste(walk[facing][index], index * CELL, row * CELL)
    for made in MADE_CELLS:
        source = walk[FACINGS[made.source_row]][made.source_column]
        sheet.paste(apply_rules(made.rules, source, part, (made.column, made.row)), made.column * CELL, made.row * CELL)
    return sheet


def edge_pixels(frame):
    """Opaque pixels of a 32x32 frame with a transparent 4-neighbour or one outside the frame."""
    return [(x, y) for y in range(frame.height) for x in range(frame.width) if frame.alpha(x, y) and _open_sides(frame, x, y)]


def _open_sides(frame, x, y):
    sides = []
    for dx, dy in NEIGHBOURS:
        nx, ny = x + dx, y + dy
        if not (0 <= nx < frame.width and 0 <= ny < frame.height) or frame.alpha(nx, ny) == 0:
            sides.append((nx, ny))
    return sides


def is_covered(frame, body, x, y):
    """An edge pixel of an overlay whose every open side is opaque in the body frame."""
    sides = _open_sides(frame, x, y)
    return bool(sides) and all(0 <= nx < body.width and 0 <= ny < body.height and body.alpha(nx, ny) for nx, ny in sides)


def invariant_problems(sheet, part, outline_set, over=None, exempt=frozenset()):
    """design.md C1's invariant on a finished (ruled, remapped, rimmed) part sheet.

    Each made cell's alpha mask equals its rules applied to its walk cell's mask; a pixel interior
    both in its walk source and in the made cell keeps the rule's colour; every edge pixel is an
    outline colour, except, with `over` (the body sheet), one whose open sides the body covers.
    `exempt` holds (column, row, x, y) hand-fix pixels, skipped by every test.
    """
    outline = {tuple(c[:3]) for c in outline_set}
    problems = []
    for made in MADE_CELLS:
        at = (made.column, made.row)
        walk = cell(sheet, made.source_column, made.source_row)
        expected = apply_rules(made.rules, walk, part, at)
        interior_source = _interior_map(walk, made.rules, part, at)
        actual = cell(sheet, made.column, made.row)
        body = cell(over, made.column, made.row) if over is not None else None
        edges = set(edge_pixels(actual))
        for y in range(CELL):
            for x in range(CELL):
                if (made.column, made.row, x, y) in exempt:
                    continue
                pixel = actual.get(x, y)
                ruled = expected.get(x, y)
                if (pixel[3] > 0) != (ruled[3] > 0):
                    problems.append(f"{part}: cell {at} pixel ({x}, {y}) differs from the {_names(made.rules)} rule's mask")
                    continue
                if pixel[3] == 0:
                    continue
                exposed = (x, y) in edges and not (body is not None and is_covered(actual, body, x, y))
                if exposed:
                    if pixel[:3] not in outline:
                        problems.append(f"{part}: cell {at} edge pixel ({x}, {y}) {png.colour_hex(pixel)} is not an outline colour")
                elif (x, y) in interior_source and pixel != ruled:
                    # Interior or covered here, interior in the walk source: the rule's colour.
                    # A pixel that was an edge in its source is exempt (its colour before the rim
                    # is not tracked).
                    problems.append(f"{part}: cell {at} pixel ({x}, {y}) is not the {_names(made.rules)} rule's colour")
    return problems


def _interior_map(walk, rules, part, at):
    """The made-cell positions whose source pixel is interior in the walk cell."""
    marker = png.blank(CELL, CELL)
    edges = set(edge_pixels(walk))
    for y in range(CELL):
        for x in range(CELL):
            if walk.alpha(x, y) and (x, y) not in edges:
                marker.set(x, y, (255, 255, 255, 255))
            elif walk.alpha(x, y):
                marker.set(x, y, (0, 0, 0, 1))
    moved = apply_rules(rules, marker, part, at)
    return {(x, y) for y in range(CELL) for x in range(CELL) if moved.get(x, y) == (255, 255, 255, 255)}


def _names(rules):
    return " then ".join(rule.name for rule in rules) or "copy"
