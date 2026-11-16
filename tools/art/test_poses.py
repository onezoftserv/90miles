"""Tests for the pose rules of design.md C1 (task 1.5), on fixture frames built here.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import unittest

import palette
import png
import poses
import rim

BLACK = (0, 0, 0)
OUTLINE_SET = [(0, 0, 0), (0x22, 0x20, 0x34), (0x45, 0x28, 0x3C), (0x32, 0x3C, 0x39)]


def figure(colour_seed, left=10, right=21, top=3, bottom=30):
    """A 32x32 walk frame: a body block with a light ring and a varied interior."""
    frame = png.blank(32, 32)
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            ring = x in (left, right) or y in (top, bottom)
            colour = (0xEE, 0xC3, 0x9A) if ring else ((x * 7 + y * 3 + colour_seed) % 200 + 40, (y * 5) % 250, (x * 11) % 250)
            frame.set(x, y, colour + (255,))
    return frame


def shirt(colour_seed):
    """An overlay: wide rows 17-23 and narrow rows 24-26, so the crouch cut leaves new edges."""
    frame = png.blank(32, 32)
    for y in range(17, 27):
        left, right = (11, 20) if y <= 23 else (13, 18)
        for x in range(left, right + 1):
            frame.set(x, y, (0x5E, 0xF0, (0xBC + colour_seed) % 256, 255))
    return frame


def hair(colour_seed):
    frame = png.blank(32, 32)
    for y in range(1, 9):
        for x in range(11, 21):
            if y > 2 or 13 <= x <= 18:
                frame.set(x, y, (0x66 + colour_seed, 0x39, 0x31, 255))
    return frame


def walk_set(make):
    """Six walk frames per facing, each one different."""
    return {facing: [make(index + 10 * row) for index in range(poses.WALK_FRAMES)] for row, facing in enumerate(poses.FACINGS)}


def mask(image):
    return [[image.get(x, y)[3] > 0 for x in range(image.width)] for y in range(image.height)]


class CrouchRuleTest(unittest.TestCase):
    def test_crouch_deletes_exactly_rows_21_to_23_and_27_to_29(self):
        frame = png.blank(32, 32)
        for y in range(32):
            for x in range(32):
                frame.set(x, y, (y, 0, 0, 255))
        made = poses.apply_rule(poses.CROUCH, frame, "fixture", (6, 0))
        kept = sorted({made.get(x, y)[0] for y in range(32) for x in range(32) if made.get(x, y)[3] > 0})
        self.assertEqual(sorted(set(range(32)) - set(kept)), [21, 22, 23, 27, 28, 29])
        self.assertEqual(poses.CROUCH.deleted_rows, frozenset({21, 22, 23, 27, 28, 29}))
        for y in range(6):
            self.assertTrue(all(made.get(x, y)[3] == 0 for x in range(32)), f"row {y} is empty")
        self.assertEqual(made.get(5, 6)[0], 0, "rows above 21 drop 6 px")
        self.assertEqual(made.get(5, 26)[0], 20)
        self.assertEqual(made.get(5, 27)[0], 24, "rows 24-26 drop 3 px")
        self.assertEqual(made.get(5, 29)[0], 26)
        self.assertEqual(made.get(5, 30)[0], 30, "the feet row stays")
        self.assertEqual(made.get(5, 31)[0], 31)


class RuleErrorTest(unittest.TestCase):
    def test_a_rule_that_pushes_a_pixel_out_of_its_cell_names_the_part_and_the_cell(self):
        frame = png.blank(32, 32)
        frame.set(28, 10, (1, 2, 3, 255))  # turned clockwise and moved 8 px down: y = 28 + 8
        with self.assertRaises(poses.PoseError) as caught:
            poses.apply_rule(poses.TURN_DOWN, frame, "hair_9", (0, 3))
        self.assertIn("hair_9", str(caught.exception))
        self.assertIn("(0, 3)", str(caught.exception))
        self.assertIn("out of", str(caught.exception))

    def test_a_rule_that_drops_a_pixel_outside_its_deleted_rows_names_the_part_and_the_cell(self):
        careless = poses.Rule("careless crouch", lambda x, y: None if y in (10, 21) else (x, y), frozenset({21}))
        frame = png.blank(32, 32)
        frame.set(4, 21, (1, 2, 3, 255))
        poses.apply_rule(careless, frame, "body_man", (6, 1))  # row 21 is the rule's own
        frame.set(4, 10, (1, 2, 3, 255))
        with self.assertRaises(poses.PoseError) as caught:
            poses.apply_rule(careless, frame, "body_man", (6, 1))
        self.assertIn("body_man", str(caught.exception))
        self.assertIn("(6, 1)", str(caught.exception))
        self.assertIn("drops", str(caught.exception))

    def test_building_a_sheet_reports_the_cell_of_the_rule_that_failed(self):
        walk = walk_set(lambda seed: figure(seed))
        walk["down"][0].set(29, 15, (9, 9, 9, 255))  # pushed out by the downed turn
        with self.assertRaises(poses.PoseError) as caught:
            poses.build_sheet(walk, "body_wide")
        self.assertIn("body_wide", str(caught.exception))
        self.assertIn("(0, 3)", str(caught.exception))


class LayoutTest(unittest.TestCase):
    def test_the_sheet_follows_the_frame_layout(self):
        walk = walk_set(lambda seed: figure(seed))
        sheet = poses.build_sheet(walk, "body")
        self.assertEqual((sheet.width, sheet.height), (320, 128))
        for row, facing in enumerate(poses.FACINGS):
            for index in range(poses.WALK_FRAMES):
                self.assertEqual(poses.cell(sheet, index, row), walk[facing][index], f"walk {facing} {index}")
            for column, source in zip(poses.SWIM_COLUMNS, poses.SWIM_FROM):
                self.assertEqual(poses.cell(sheet, column, row), walk[facing][source], f"swim {facing} {column}")
        self.assertEqual(poses.cell(sheet, poses.DEAD_COLUMN, poses.DOWNED_ROW), poses.cell(sheet, poses.DOWNED_COLUMNS[0], poses.DOWNED_ROW))
        used = {(c.column, c.row) for c in poses.MADE_CELLS} | {(i, r) for r in range(3) for i in range(6)}
        self.assertEqual(len(used), 33)
        for row in range(4):
            for column in range(10):
                if (column, row) not in used:
                    self.assertTrue(poses.cell(sheet, column, row).is_empty(), f"unused cell ({column}, {row})")

    def test_downed_lies_the_body_down_and_keeps_the_head_upright_with_a_chest_lift(self):
        # art-sprite-polish D8: the rows from the neck down turn clockwise and drop as before; the
        # head block above the neck moves to their end unturned, so the face stays upright.
        walk = walk_set(lambda seed: figure(seed))
        sheet = poses.build_sheet(walk, "body")
        source = walk["down"][0]
        downed = poses.cell(sheet, 0, poses.DOWNED_ROW)
        lifted = poses.cell(sheet, 1, poses.DOWNED_ROW)
        dx, dy = poses.HEAD_SHIFT
        for y in range(32):
            for x in range(32):
                if y in poses.LIE_DELETED_ROWS:
                    continue
                if y < poses.NECK_ROW:
                    tx, ty = x + dx, y + dy
                else:
                    tx, ty = 31 - y, x + poses.DOWNED_DROP
                # every drawn pixel lands where the rule sends it (the map is not one-to-one over
                # the clear pixels: a clear head-row pixel can share a target with the turned body)
                if source.alpha(x, y):
                    self.assertEqual(downed.get(tx, ty), source.get(x, y), f"({x}, {y})")
        for y in range(31):
            for x in range(32):
                expected = downed.get(x, y + 1) if x in poses.CHEST_COLUMNS else downed.get(x, y)
                self.assertEqual(lifted.get(x, y), expected, f"({x}, {y})")


## balsero_art.tres water_row: the rows above it are drawn while swimming.
WATER_ROW = 19


class SwimBobTest(unittest.TestCase):
    """art-sprite-polish D1 (C19, SP3): the two swim frames bob above the water line."""

    def test_the_swim_cells_come_from_walk_frames_1_and_3(self):
        self.assertEqual(poses.SWIM_FROM, (1, 3), "walk 1 and 4 are both high steps; 1 and 3 bob")

    def test_the_tracked_body_sheets_two_swim_cells_differ_above_the_water_row(self):
        for name in ("body_man", "body_woman"):
            sheet = png.read_png(palette.ART / "characters" / "parts" / f"{name}.png")
            for row, facing in enumerate(poses.FACINGS):
                first = poses.cell(sheet, poses.SWIM_COLUMNS[0], row).crop(0, 0, poses.CELL, WATER_ROW)
                second = poses.cell(sheet, poses.SWIM_COLUMNS[1], row).crop(0, 0, poses.CELL, WATER_ROW)
                self.assertNotEqual(first.pixels, second.pixels, f"{name} swim {facing}: the two frames differ above the line")


class LyingPoseTest(unittest.TestCase):
    """art-sprite-polish D8 (C25, SP9): a downed or dead body lies along the ground, face upright."""

    def test_every_head_row_stays_one_row_so_the_eyes_stay_side_by_side(self):
        for y in range(poses.NECK_ROW):
            self.assertEqual(len({poses.LIE.mapping(x, y)[1] for x in range(poses.CELL)}), 1, f"head row {y}")
            self.assertEqual([poses.LIE.mapping(x, y)[0] - x for x in range(poses.CELL)], [poses.HEAD_SHIFT[0]] * poses.CELL)

    def test_the_neck_and_shoulder_rows_are_left_out_and_the_head_meets_the_body(self):
        self.assertEqual(poses.LIE.deleted_rows, poses.LIE_DELETED_ROWS)
        for y in poses.LIE_DELETED_ROWS:
            self.assertTrue(all(poses.LIE.mapping(x, y) is None for x in range(poses.CELL)), f"row {y}")
        body_end = poses.CELL - 1 - (max(poses.LIE_DELETED_ROWS) + 1)
        figure_left = 7  # the widest head row's first pixel on a MetroCity walk frame
        self.assertEqual(figure_left + poses.HEAD_SHIFT[0], body_end + 1, "the head starts on the column after the body")

    def test_downed_breath_and_dead_are_made_by_the_lying_rule(self):
        rules = {(m.column, m.row): m.rules for m in poses.MADE_CELLS}
        self.assertEqual(rules[(poses.DOWNED_COLUMNS[0], poses.DOWNED_ROW)], (poses.LIE,))
        self.assertEqual(rules[(poses.DOWNED_COLUMNS[1], poses.DOWNED_ROW)], (poses.LIE, poses.CHEST_LIFT))
        self.assertEqual(rules[(poses.DEAD_COLUMN, poses.DOWNED_ROW)], (poses.LIE,))

    def test_the_tracked_lying_figures_are_wider_than_tall_on_the_same_feet_line(self):
        for name in ("body_man", "body_woman"):
            sheet = png.read_png(palette.ART / "characters" / "parts" / f"{name}.png")
            for column in (poses.DOWNED_COLUMNS[0], poses.DEAD_COLUMN):
                cell = poses.cell(sheet, column, poses.DOWNED_ROW)
                xs = [x for y in range(32) for x in range(32) if cell.alpha(x, y)]
                ys = [y for y in range(32) for x in range(32) if cell.alpha(x, y)]
                self.assertGreater(max(xs) - min(xs), max(ys) - min(ys), f"{name} column {column} lies wider than tall")
                self.assertEqual(max(ys), 30, f"{name} column {column}: the feet line, row 30, is kept")


class CompositeTest(unittest.TestCase):
    def test_each_rule_per_layer_then_composited_equals_the_rule_on_the_composite(self):
        body = walk_set(lambda seed: figure(seed))
        top = walk_set(shirt)
        head = walk_set(hair)
        per_layer = png.over(png.over(poses.build_sheet(body, "body"), poses.build_sheet(top, "shirt")), poses.build_sheet(head, "hair"))
        composite = {facing: [png.over(png.over(body[facing][i], top[facing][i]), head[facing][i]) for i in range(poses.WALK_FRAMES)] for facing in poses.FACINGS}
        self.assertEqual(per_layer, poses.build_sheet(composite, "composite"))


class InvariantAfterRimTest(unittest.TestCase):
    def setUp(self):
        self.body = rim.rim(poses.build_sheet(walk_set(lambda seed: figure(seed)), "body_fixture"), OUTLINE_SET, cell=32, outline=BLACK)
        self.overlay_raw = poses.build_sheet(walk_set(shirt), "shirt_fixture")
        self.overlay = rim.rim(self.overlay_raw, OUTLINE_SET, cell=32, over=self.body, outline=BLACK)

    def test_every_made_cell_keeps_the_rule_applied_to_its_walk_mask(self):
        for sheet in (self.body, self.overlay):
            for made in poses.MADE_CELLS:
                walk_cell = poses.cell(sheet, made.source_column, made.source_row)
                expected = poses.apply_rules(made.rules, walk_cell, "fixture", (made.column, made.row))
                self.assertEqual(mask(poses.cell(sheet, made.column, made.row)), mask(expected), f"cell ({made.column}, {made.row})")

    def test_the_invariant_holds_for_the_body_and_the_overlay_over_it(self):
        self.assertEqual(poses.invariant_problems(self.body, "body_fixture", OUTLINE_SET), [])
        self.assertEqual(poses.invariant_problems(self.overlay, "shirt_fixture", OUTLINE_SET, over=self.body), [])

    def test_a_crouch_cut_leaves_a_covered_edge_pixel_that_keeps_the_rules_colour(self):
        covered = []
        for made in poses.MADE_CELLS:
            if made.rules != (poses.CROUCH,):
                continue
            rect = poses.cell_rect(made.column, made.row)
            rimmed = poses.cell(self.overlay, made.column, made.row)
            raw = poses.cell(self.overlay_raw, made.column, made.row)
            body = poses.cell(self.body, made.column, made.row)
            for (x, y) in poses.edge_pixels(rimmed):
                if poses.is_covered(rimmed, body, x, y):
                    covered.append((rect, x, y))
                    self.assertEqual(rimmed.get(x, y), raw.get(x, y), "a covered edge keeps the rule's colour")
                else:
                    self.assertEqual(rimmed.get(x, y)[:3], BLACK)
        self.assertTrue(covered, "the fixture's crouch cut leaves covered edge pixels")

    def test_without_over_the_same_pixels_would_be_rimmed(self):
        alone = rim.rim(self.overlay_raw, OUTLINE_SET, cell=32, outline=BLACK)
        problems = poses.invariant_problems(alone, "shirt_fixture", OUTLINE_SET)
        self.assertEqual(problems, [])
        self.assertNotEqual(alone, self.overlay)

    def test_an_edge_pixel_that_is_not_an_outline_colour_is_reported(self):
        broken = self.body.copy()
        rect = poses.cell_rect(6, 0)
        x, y = poses.edge_pixels(poses.cell(self.body, 6, 0))[0]
        broken.set(rect[0] + x, rect[1] + y, (0xD9, 0xA0, 0x66, 255))
        problems = poses.invariant_problems(broken, "body_fixture", OUTLINE_SET)
        self.assertEqual(len(problems), 1)
        self.assertIn("body_fixture", problems[0])
        self.assertIn("(6, 0)", problems[0])


if __name__ == "__main__":
    unittest.main()
