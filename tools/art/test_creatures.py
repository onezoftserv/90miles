"""Tests for creatures.py, the creature art builder of design.md D16 and K60 to K62, on a fixture
pack and fixes folder written to a scratch folder: cut and recolour a pack rect, refuse a colour
the recipe does not map, drop lone pixels, recolour a piece's edge, lay the hand source under the
pack layers, rim each cell, refuse a sheet whose cell edge is not an outline colour, write nothing
when a sheet is refused or the out folder is a download folder, and give the same bytes again.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import json
import pathlib
import tempfile
import unittest

import creatures
import png

BLACK = (0, 0, 0)
NAVY = (0x22, 0x20, 0x34)
WHITE = (0xFF, 0xFF, 0xFF)
PALE = (0xCB, 0xDB, 0xFC)
RED = (0xAC, 0x32, 0x32)
PALETTE = [BLACK, NAVY, WHITE, PALE, RED]
OUTLINE = [BLACK, NAVY]
CREAM = (0xDF, 0xEF, 0xD7)  # off-palette pack colours
CYAN = (0x6D, 0xC3, 0xCB)


def block(width, height, fill, edge=None, at=(0, 0), size=None):
    """An image holding a filled rect at `at`, its edge in `edge` (when given)."""
    w, h = size or (width, height)
    image = png.blank(w, h)
    for y in range(height):
        for x in range(width):
            on_edge = x in (0, width - 1) or y in (0, height - 1)
            image.set(at[0] + x, at[1] + y, (edge if edge and on_edge else fill) + (255,))
    return image


class CreatureArtTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        root = pathlib.Path(self._dir.name)
        self.packs = root / "packs"
        self.fixes = root / "fixes"
        self.out = root / "out"
        (self.packs / "oga" / "fixture").mkdir(parents=True)
        self.fixes.mkdir()
        sheet = png.blank(32, 16)
        for y in range(2, 6):
            for x in range(2, 8):
                sheet.set(x, y, (CREAM if 3 <= x <= 6 and 3 <= y <= 4 else CYAN) + (255,))
        sheet.set(12, 12, CREAM + (255,))  # a lone droplet
        sheet.set(20, 3, (0x12, 0x34, 0x56, 255))  # a colour no recipe maps
        png.write_png(self.packs / "oga" / "fixture" / "sheet.png", sheet)
        png.write_png(self.fixes / "hand.png", block(4, 4, RED, BLACK, at=(1, 1), size=(16, 8)))

    def tearDown(self):
        self._dir.cleanup()

    def recipe(self, layers, rim=False, size=(16, 8), cell=(8, 8)):
        return {
            "sources": {"fixture": "oga/fixture/sheet.png"},
            "sheets": [{"id": "bicho", "size": list(size), "cell": list(cell), "layers": layers, "rim": rim}],
        }

    def build(self, recipe):
        return creatures.build(recipe, self.packs, self.fixes, self.out, PALETTE, OUTLINE, log=lambda _line: None)

    def splash(self, **extra):
        layer = {"from": "fixture", "rect": [2, 2, 6, 4], "at": [9, 2], "map": {"#dfefd7": "#ffffff", "#6dc3cb": "#cbdbfc"}}
        layer.update(extra)
        return layer

    def test_a_pack_rect_is_cut_recoloured_and_pasted_with_its_edge_recoloured(self):
        sheet = self.build(self.recipe([{"hand": "hand.png"}, self.splash(outline="#000000")]))["creatures/bicho.png"]
        self.assertEqual(sheet.get(1, 1), BLACK + (255,), "the hand layer's outline")
        self.assertEqual(sheet.get(2, 2), RED + (255,), "and its fill")
        self.assertEqual(sheet.get(9, 2), BLACK + (255,), "the piece's edge is black")
        self.assertEqual(sheet.get(10, 3), WHITE + (255,), "cream mapped to white")
        bare = creatures.pack_layer(self.splash(), creatures.Sources({"fixture": "oga/fixture/sheet.png"}, self.packs), set(PALETTE), "t")
        self.assertEqual(bare.get(0, 0), PALE + (255,), "cyan mapped to pale where no outline is asked for")
        self.assertTrue((self.out / "creatures" / "bicho.png").is_file())

    def test_a_colour_the_recipe_does_not_map_is_refused_naming_it(self):
        layer = {"from": "fixture", "rect": [18, 2, 4, 4], "at": [0, 0], "map": {}}
        with self.assertRaisesRegex(creatures.CreatureArtError, "#123456"):
            self.build(self.recipe([layer]))
        self.assertFalse(self.out.exists(), "nothing written")

    def test_lone_pixels_are_dropped(self):
        layer = {"from": "fixture", "rect": [10, 10, 4, 4], "at": [2, 2], "map": {"#dfefd7": "#ffffff"}}
        kept = creatures.pack_layer(layer, creatures.Sources({"fixture": "oga/fixture/sheet.png"}, self.packs), set(PALETTE), "t")
        self.assertFalse(kept.is_empty())
        layer["drop_lone"] = True
        dropped = creatures.pack_layer(layer, creatures.Sources({"fixture": "oga/fixture/sheet.png"}, self.packs), set(PALETTE), "t")
        self.assertTrue(dropped.is_empty())

    def test_a_cell_edge_that_is_not_an_outline_colour_is_refused_unless_rimmed(self):
        recipe = self.recipe([self.splash()])
        with self.assertRaisesRegex(creatures.CreatureArtError, r"cell \(1, 0\)"):
            self.build(recipe)
        self.assertFalse(self.out.exists())
        sheet = self.build(self.recipe([self.splash()], rim=True))["creatures/bicho.png"]
        self.assertEqual(sheet.get(9, 2), NAVY + (255,), "the rim recolours to the nearest outline colour")

    def test_a_hand_source_of_the_wrong_size_or_outside_the_fixes_is_refused(self):
        png.write_png(self.fixes / "small.png", png.blank(8, 8))
        with self.assertRaisesRegex(creatures.CreatureArtError, "8x8, not 16x8"):
            self.build(self.recipe([{"hand": "small.png"}]))
        with self.assertRaisesRegex(creatures.CreatureArtError, "no hand-drawn source"):
            self.build(self.recipe([{"hand": "../packs/oga/fixture/sheet.png"}]))

    def test_a_piece_off_the_sheet_or_a_source_outside_the_packs_is_refused(self):
        with self.assertRaisesRegex(creatures.CreatureArtError, "off the 16x8 sheet"):
            self.build(self.recipe([self.splash(at=[12, 2])]))
        recipe = self.recipe([self.splash()])
        recipe["sources"]["fixture"] = "../fixes/hand.png"
        with self.assertRaisesRegex(creatures.CreatureArtError, "outside the packs root"):
            self.build(recipe)

    def test_nothing_is_written_inside_a_download_folder(self):
        with self.assertRaisesRegex(creatures.CreatureArtError, "download folder"):
            creatures.build(self.recipe([{"hand": "hand.png"}]), self.packs, self.fixes, self.packs / "oga" / "x", PALETTE, OUTLINE, log=lambda _line: None)

    def test_a_second_run_gives_the_same_bytes(self):
        recipe = self.recipe([{"hand": "hand.png"}, self.splash(outline="#000000", drop_lone=True)])
        self.build(recipe)
        first = (self.out / "creatures" / "bicho.png").read_bytes()
        self.build(recipe)
        self.assertEqual((self.out / "creatures" / "bicho.png").read_bytes(), first)

    def test_the_shipped_recipe_names_tracked_hand_sources_and_whole_cells(self):
        recipe = creatures.load_recipe()
        ids = []
        for entry in recipe["sheets"]:
            ids.append(entry["id"])
            width, height = entry["size"]
            cell_w, cell_h = entry["cell"]
            self.assertEqual((width % cell_w, height % cell_h), (0, 0), entry["id"])
            for layer in entry["layers"]:
                if "hand" in layer:
                    self.assertTrue((creatures.DEFAULT_FIXES / layer["hand"]).is_file(), layer["hand"])
                else:
                    self.assertIn(layer["from"], recipe["sources"])
        self.assertEqual(sorted(ids), ["land_crab", "reef_shark", "seagull"])


if __name__ == "__main__":
    unittest.main()
