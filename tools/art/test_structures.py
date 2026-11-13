"""Tests for structures.py, the structure art builder of design.md D18 and K80 to K89, on a fixture
pack and fixture hand sources written to a scratch folder: cut, flip, turn and recolour pack
pieces, key out baked shadows, stack hand pieces with the erase colour, expand parts, rim each
frame in its own cell, and refuse what would put an unchosen or off-palette colour in the game.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import json
import pathlib
import tempfile
import unittest

import png
import structures

GREEN = (0x10, 0xC0, 0x10)  # off-palette pack colours
BROWN = (0x80, 0x50, 0x20)
LEAF = (0x6A, 0xBE, 0x30)
WOOD = (0x8F, 0x56, 0x3B)
SAND = (0xD9, 0xA0, 0x66)
BLACK = (0, 0, 0)
LINE = (0x45, 0x28, 0x3C)
PALETTE = [LEAF, WOOD, SAND, BLACK, LINE]
OUTLINE = [BLACK, LINE]
ERASE = (0xFF, 0x00, 0xFF)


def filled(colour, width, height, alpha=255):
    image = png.blank(width, height)
    for y in range(height):
        for x in range(width):
            image.set(x, y, colour + (alpha,))
    return image


def opaque(image):
    return {(x, y) for y in range(image.height) for x in range(image.width) if image.alpha(x, y)}


class Fixture:
    """A pack folder, a fixes folder and an out folder in one scratch directory."""

    def __init__(self, root):
        self.root = pathlib.Path(root)
        self.packs = self.root / "packs"
        self.fixes = self.root / "fixes"
        self.out = self.root / "out"
        for folder in (self.packs / "itch" / "pack", self.fixes, self.out):
            folder.mkdir(parents=True)
        sheet = png.blank(32, 16)
        for y in range(2, 10):
            for x in range(2, 6):
                sheet.set(x, y, GREEN + (255,))
        sheet.set(6, 9, BROWN + (102,))  # a baked half-transparent shadow
        for y in range(4, 12):
            for x in range(18, 30):
                sheet.set(x, y, BROWN + (255,))
        png.write_png(self.packs / "itch" / "pack" / "sheet.png", sheet)

    def hand(self, name, image):
        png.write_png(self.fixes / name, image)

    def recipe(self, sheets, parts=None):
        return {
            "sources": {"pack": "itch/pack/sheet.png"},
            "maps": {"leaf": {"#10c010": "#6abe30"}, "wood": {"#805020": "#8f563b"}},
            "parts": parts or {},
            "sheets": sheets,
        }

    def build(self, recipe, out=None):
        return structures.build(recipe, self.packs, self.fixes, out or self.out, PALETTE, OUTLINE, log=lambda *_: None)


class PieceTests(unittest.TestCase):
    def test_flip_and_turn_move_pixels_as_named(self):
        image = png.blank(3, 2)
        image.set(0, 0, LEAF + (255,))
        self.assertEqual(structures.flipped(image, "h").get(2, 0), LEAF + (255,))
        self.assertEqual(structures.flipped(image, "v").get(0, 1), LEAF + (255,))
        turned = structures.turned(image, 90)
        self.assertEqual((turned.width, turned.height), (2, 3))
        self.assertEqual(turned.get(1, 0), LEAF + (255,), "clockwise: the top-left goes to the top-right")
        with self.assertRaises(structures.StructureError):
            structures.turned(image, 45)
        with self.assertRaises(structures.StructureError):
            structures.flipped(image, "x")

    def test_recolour_maps_keys_out_and_drops_partial_alpha(self):
        piece = png.blank(3, 1)
        piece.set(0, 0, GREEN + (255,))
        piece.set(1, 0, BROWN + (255,))
        piece.set(2, 0, GREEN + (102,))
        out = structures.recoloured(piece, {GREEN: LEAF}, {BROWN}, "piece")
        self.assertEqual(out.get(0, 0), LEAF + (255,))
        self.assertEqual(out.alpha(1, 0), 0, "an erase colour is keyed out")
        self.assertEqual(out.alpha(2, 0), 0, "a baked shadow is keyed out")

    def test_recolour_refuses_a_colour_the_map_does_not_name(self):
        piece = filled(BROWN, 1, 1)
        with self.assertRaisesRegex(structures.StructureError, "#805020"):
            structures.recoloured(piece, {GREEN: LEAF}, set(), "piece")

    def test_draw_clips_and_erases(self):
        frame = filled(WOOD, 4, 4)
        piece = png.blank(3, 1)
        piece.set(0, 0, ERASE + (255,))
        piece.set(2, 0, LEAF + (255,))
        structures.draw(frame, piece, (2, 1))
        self.assertEqual(frame.alpha(2, 1), 0, "#ff00ff clears")
        self.assertEqual(frame.get(3, 1), WOOD + (255,), "the pixel off the frame is clipped")

    def test_parts_expand_with_their_offset_added(self):
        recipe = {"parts": {"log": [{"hand": "a.png", "at": [1, 2]}], "two": [{"part": "log", "at": [10, 0]}]}}
        flat = structures.layers_of([{"part": "two", "at": [0, 5]}], recipe)
        self.assertEqual(flat, [{"hand": "a.png", "at": [11, 7]}])
        with self.assertRaisesRegex(structures.StructureError, "no part"):
            structures.layers_of([{"part": "none"}], recipe)

    def test_a_part_name_that_is_not_text_is_refused(self):
        recipe = {"parts": {"log": [{"hand": "a.png"}]}}
        for name in (["log"], {"log": 1}, 3):
            with self.assertRaisesRegex(structures.StructureError, "is not a part name"):
                structures.layers_of([{"part": name}], recipe)

    def test_parts_that_name_themselves_are_refused(self):
        recipe = {"parts": {"loop": [{"part": "loop"}]}}
        with self.assertRaisesRegex(structures.StructureError, "too deep"):
            structures.layers_of([{"part": "loop"}], recipe)


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.fixture = Fixture(self.scratch.name)

    def tearDown(self):
        self.scratch.cleanup()

    def test_a_sheet_lays_its_frames_side_by_side_each_rimmed_in_its_cell(self):
        self.fixture.hand("block.png", filled(WOOD, 4, 4))
        sheet = {"out": "structures/thing.png", "frame": [8, 8], "frames": [
            [{"hand": "block.png", "at": [2, 2]}],
            [{"cut": "pack", "rect": [0, 0, 8, 12], "map": "leaf"}],
        ]}
        made = self.fixture.build(self.fixture.recipe([sheet]))["structures/thing.png"]
        self.assertEqual((made.width, made.height), (16, 8))
        self.assertEqual(made.get(3, 3), WOOD + (255,), "the inside keeps its colour")
        self.assertEqual(made.get(2, 2), LINE + (255,), "the edge takes its nearest outline colour")
        self.assertEqual(opaque(made) & {(x, 8) for x in range(16)}, set(), "the cut is clipped to the frame")
        self.assertEqual(made.get(10, 7), LINE + (255,), "the second frame's edge on the cell border is rimmed")
        self.assertEqual(made.alpha(14, 9 % 8), 0, "the baked shadow pixel is keyed out")
        written = png.read_png(self.fixture.out / "structures" / "thing.png")
        self.assertEqual(written, made)

    def test_a_forced_outline_colour_rims_every_edge_with_it(self):
        self.fixture.hand("block.png", filled(LEAF, 4, 4))
        sheet = {"out": "structures/thing.png", "frame": [6, 6], "outline": "#000000", "frames": [[{"hand": "block.png", "at": [1, 1]}]]}
        made = self.fixture.build(self.fixture.recipe([sheet]))["structures/thing.png"]
        self.assertEqual(made.get(1, 1), BLACK + (255,))

    def test_a_run_again_writes_the_same_bytes(self):
        self.fixture.hand("block.png", filled(WOOD, 4, 4))
        recipe = self.fixture.recipe([{"out": "structures/thing.png", "frame": [8, 8], "frames": [
            [{"hand": "block.png", "at": [1, 1]}, {"cut": "pack", "rect": [18, 4, 8, 8], "map": "wood", "flip": "h", "turn": 90, "at": [0, 0]}]]}])
        self.fixture.build(recipe)
        first = (self.fixture.out / "structures" / "thing.png").read_bytes()
        self.fixture.build(recipe)
        self.assertEqual((self.fixture.out / "structures" / "thing.png").read_bytes(), first)

    def test_an_off_palette_hand_pixel_refuses_every_sheet(self):
        self.fixture.hand("good.png", filled(WOOD, 4, 4))
        self.fixture.hand("bad.png", filled(GREEN, 2, 2))
        recipe = self.fixture.recipe([
            {"out": "structures/good.png", "frame": [8, 8], "frames": [[{"hand": "good.png"}]]},
            {"out": "structures/bad.png", "frame": [8, 8], "frames": [[{"hand": "bad.png"}]]},
        ])
        with self.assertRaisesRegex(structures.StructureError, "bad.png: #10c010"):
            self.fixture.build(recipe)
        self.assertFalse((self.fixture.out / "structures").exists(), "nothing is written when a sheet is refused")

    def test_a_half_transparent_hand_pixel_is_refused(self):
        self.fixture.hand("soft.png", filled(WOOD, 2, 2, alpha=128))
        recipe = self.fixture.recipe([{"out": "structures/soft.png", "frame": [4, 4], "frames": [[{"hand": "soft.png"}]]}])
        with self.assertRaisesRegex(structures.StructureError, "half-transparent"):
            self.fixture.build(recipe)

    def test_a_cut_off_the_sheet_or_an_unknown_map_is_refused(self):
        for layer, message in (
            ({"cut": "pack", "rect": [30, 0, 8, 8], "map": "leaf"}, "off the 32x16"),
            ({"cut": "pack", "rect": [0, 0, 8, 8], "map": "none"}, "no map named"),
            ({"cut": "nowhere", "rect": [0, 0, 8, 8], "map": "leaf"}, "no source named"),
            ({"hand": "../escape.png"}, "file name in the fixes folder"),
        ):
            with self.subTest(message=message):
                recipe = self.fixture.recipe([{"out": "structures/x.png", "frame": [8, 8], "frames": [[layer]]}])
                with self.assertRaisesRegex(structures.StructureError, message):
                    self.fixture.build(recipe)

    def test_nothing_is_written_inside_a_download_folder_or_outside_the_out_folder(self):
        self.fixture.hand("block.png", filled(WOOD, 2, 2))
        sheet = {"out": "structures/x.png", "frame": [4, 4], "frames": [[{"hand": "block.png"}]]}
        with self.assertRaisesRegex(structures.StructureError, "download folder itch/"):
            self.fixture.build(self.fixture.recipe([sheet]), out=self.fixture.packs / "itch" / "pack")
        escape = dict(sheet, out="../x.png")
        with self.assertRaisesRegex(structures.StructureError, "under the out folder"):
            self.fixture.build(self.fixture.recipe([escape]))

    def test_the_tracked_recipe_reads_and_names_only_tracked_hand_sources(self):
        recipe = structures.load_recipe()
        names = set()
        for sheet in recipe["sheets"]:
            for frame in sheet["frames"]:
                for layer in structures.layers_of(frame, recipe):
                    if "hand" in layer:
                        names.add(layer["hand"])
        for name in sorted(names):
            self.assertTrue((structures.DEFAULT_FIXES / name).is_file(), name)
        listed = {path.name for path in structures.DEFAULT_FIXES.glob("*.png")}
        self.assertEqual(listed - names, set(), "every hand source is used")

    def test_a_recipe_without_sheets_is_refused(self):
        path = pathlib.Path(self.scratch.name) / "recipe.json"
        path.write_text(json.dumps({"sources": {}}), encoding="utf-8")
        with self.assertRaisesRegex(structures.StructureError, "no \"sheets\""):
            structures.load_recipe(path)


if __name__ == "__main__":
    unittest.main()
