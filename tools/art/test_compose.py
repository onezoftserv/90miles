"""Tests for compose.py, the part builder of design.md C1 (D4 as replaced), on a fixture pack
written to a scratch folder: cut the 18 walk frames, apply the pose rules, blend the hand fix,
remap, then rim."""
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

import compose
import png
import poses

HERE = pathlib.Path(__file__).resolve().parent
OUTLINE_SET = [(0, 0, 0), (0x22, 0x20, 0x34), (0x45, 0x28, 0x3C), (0x32, 0x3C, 0x39)]
PALETTE = OUTLINE_SET + [(0xEE, 0xC3, 0x9A), (0xFF, 0xED, 0xDE), (0x5E, 0xF0, 0xBC), (0x66, 0x39, 0x31), (0xFF, 0xFF, 0xFF)]
SKIN = (0xFF, 0xD3, 0xAA)  # off-palette: the colour map sends it to #eec39a
SHIRT = (0x80, 0x80, 0x80)  # off-palette: the colour map sends it to the key colour
HAIR = (0x66, 0x39, 0x31)


def metro_sheet(bands, wide_down=False):
    """A 768-wide MetroCity-like sheet: 24 columns of 32x32 per band, each frame different."""
    sheet = png.blank(768, 32 * len(bands))
    for band, kind in enumerate(bands):
        for column in range(24):
            frame = png.blank(32, 32)
            for y in range(32):
                for x in range(32):
                    if kind == "body" and 10 <= x <= 21 and 3 + column % 2 <= y <= 30:
                        frame.set(x, y, SKIN + (255,))
                    elif kind == "shirt" and 11 <= x <= 20 and 17 <= y <= 26 and (y <= 23 or 13 <= x <= 18):
                        frame.set(x, y, SHIRT + (255,))
                    elif kind == "hair" and 11 <= x <= 20 and 1 <= y <= 8:
                        frame.set(x, y, HAIR + (255,))
            if wide_down and column == 0:
                frame.set(29, 15, SKIN + (255,))
            sheet.paste(frame, column * 32, band * 32)
    return sheet


class ComposeTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        root = pathlib.Path(self.scratch.name)
        self.packs = root / "packs"
        self.fixes = root / "fixes"
        self.out = root / "parts"
        (self.packs / "itch" / "fake").mkdir(parents=True)
        self.fixes.mkdir()
        png.write_png(self.packs / "itch" / "fake" / "Character Model.png", metro_sheet(["shirt", "body"]))
        png.write_png(self.packs / "itch" / "fake" / "Hairs.png", metro_sheet(["hair", "hair"]))
        png.write_png(self.packs / "itch" / "fake" / "Wide.png", metro_sheet(["body"], wide_down=True))
        fix = png.blank(poses.SHEET_WIDTH, poses.SHEET_HEIGHT)
        fix.set(6 * 32 + 12, 0 * 32 + 20, (0x22, 0x20, 0x34, 255))  # a knee pixel in crouch cell (6, 0)
        fix.set(6 * 32 + 15, 0 * 32 + 30, (0xFF, 0x00, 0xFF, 255))  # #ff00ff erases
        png.write_png(self.fixes / "body_fixture.png", fix)
        self.parts = [
            {"id": "body_fixture", "file": "itch/fake/Character Model.png", "band": 1, "layer": "body",
             "colour_map": {"#ffd3aa": "#eec39a"}, "strict": True, "outline": "#000000"},
            {"id": "shirt_fixture", "file": "itch/fake/Character Model.png", "band": 0, "layer": "outfit",
             "colour_map": {"#808080": "#5ef0bc"}, "outline": "#000000", "over": "body_fixture"},
            {"id": "hair_fixture", "file": "itch/fake/Hairs.png", "band": 1, "layer": "hair",
             "outline": "#000000", "over": "body_fixture"},
        ]

    def tearDown(self):
        self.scratch.cleanup()

    def build(self, parts=None):
        return compose.build_parts(parts or self.parts, self.packs, self.fixes, self.out, PALETTE, OUTLINE_SET, exclude=[(0x5E, 0xF0, 0xBC)], log=lambda *_: None)

    def test_each_part_is_written_on_the_frame_layout(self):
        built = self.build()
        self.assertEqual(sorted(built), ["body_fixture", "hair_fixture", "shirt_fixture"])
        for part_id in built:
            sheet = png.read_png(self.out / f"{part_id}.png")
            self.assertEqual((sheet.width, sheet.height), (320, 128))
            self.assertEqual(sheet, built[part_id])

    def test_the_walk_cells_are_the_bands_walk_frames_and_the_left_facing_is_dropped(self):
        body = self.build()["body_fixture"]
        source = png.read_png(self.packs / "itch" / "fake" / "Character Model.png")
        for row, facing in enumerate(poses.FACINGS):
            for index in range(poses.WALK_FRAMES):
                cut = source.crop((poses.SOURCE_COLUMNS[facing] + index) * 32, 32, 32, 32)
                made = poses.cell(body, index, row)
                self.assertEqual([[made.alpha(x, y) > 0 for x in range(32)] for y in range(32)], [[cut.alpha(x, y) > 0 for x in range(32)] for y in range(32)])

    def test_the_colour_map_the_fix_the_remap_and_the_rim_all_apply(self):
        body = self.build()["body_fixture"]
        self.assertEqual(body.get(15, 15), (0xEE, 0xC3, 0x9A, 255), "#ffd3aa mapped to #eec39a")
        self.assertEqual(body.get(10, 15), (0, 0, 0, 255), "the edge rimmed in #000000")
        self.assertEqual(body.get(6 * 32 + 12, 20), (0x22, 0x20, 0x34, 255), "the fix replaces")
        self.assertEqual(body.alpha(6 * 32 + 15, 30), 0, "#ff00ff erases")
        self.assertNotIn((0xFF, 0x00, 0xFF), body.colours())

    def test_the_built_parts_keep_the_invariant(self):
        built = self.build()
        exempt = compose.fix_pixels(png.read_png(self.fixes / "body_fixture.png"))
        self.assertEqual(poses.invariant_problems(built["body_fixture"], "body_fixture", OUTLINE_SET, exempt=exempt), [])
        for part_id in ("shirt_fixture", "hair_fixture"):
            self.assertEqual(poses.invariant_problems(built[part_id], part_id, OUTLINE_SET, over=built["body_fixture"]), [])

    def test_the_overlays_key_colours_survive_and_covered_edges_are_not_rimmed(self):
        shirt = self.build()["shirt_fixture"]
        self.assertIn((0x5E, 0xF0, 0xBC), shirt.colours())
        self.assertEqual(shirt.get(11, 20), (0x5E, 0xF0, 0xBC, 255), "its left side lies on the body")

    def test_a_rule_that_pushes_a_pixel_out_fails_naming_the_part_and_the_cell(self):
        wide = [{"id": "body_wide", "file": "itch/fake/Wide.png", "band": 0, "layer": "body", "outline": "#000000"}]
        with self.assertRaises(poses.PoseError) as caught:
            self.build(wide)
        self.assertIn("body_wide", str(caught.exception))
        self.assertIn("(0, 3)", str(caught.exception))

    def test_a_part_id_or_file_that_leaves_its_folder_is_refused(self):
        for bad in ({"id": "../evil", "file": "itch/fake/Hairs.png"}, {"id": "hair_x", "file": "../../outside.png"}):
            part = {"band": 0, "layer": "hair", "outline": "#000000"}
            part.update(bad)
            with self.assertRaises(compose.PartError):
                self.build([part])

    def test_an_overlay_needs_its_body_built_first(self):
        with self.assertRaises(compose.PartError) as caught:
            self.build([self.parts[2]])
        self.assertIn("body_fixture", str(caught.exception))


class ComposeCommandTest(unittest.TestCase):
    def test_the_command_builds_the_listed_parts_from_the_packs_root(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = pathlib.Path(scratch)
            (root / "packs" / "itch" / "fake").mkdir(parents=True)
            png.write_png(root / "packs" / "itch" / "fake" / "Hairs.png", metro_sheet(["hair"]))
            parts = root / "parts.json"
            parts.write_text(json.dumps({"parts": [{"id": "hair_fixture", "file": "itch/fake/Hairs.png", "band": 0, "layer": "hair", "outline": "#000000"}]}), encoding="utf-8")
            command = [sys.executable, "-I", str(HERE / "compose.py"), "--packs", str(root / "packs"), "--parts", str(parts), "--fixes", str(root / "fixes"), "--out", str(root / "out")]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((root / "out" / "hair_fixture.png").exists())
            self.assertIn("hair_fixture", result.stdout)

    def test_the_shipped_part_list_loads(self):
        parts = compose.load_parts(HERE / "look_parts.json")
        self.assertIsInstance(parts, list)


if __name__ == "__main__":
    unittest.main()
