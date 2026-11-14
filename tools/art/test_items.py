"""Tests for items.py, the item icon builder of design.md D17, D21 and K70 to K79, on a fixture
pack written to a scratch folder: cut, recolour, trim and shift a pack icon, outline it in the
recipe's one colour, check the 14x14 box and the silhouettes, and write nothing when an icon is
refused.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import pathlib
import tempfile
import unittest

import items
import png

BROWN = (0x9B, 0x67, 0x42)  # off-palette pack colours
DARK = (0x0D, 0x0D, 0x0D)
GREY = (0x9B, 0xAD, 0xB7)
SAND = (0xD9, 0xA0, 0x66)
BLACK = (0, 0, 0)
WHITE = (0xFF, 0xFF, 0xFF)
PALETTE = [BLACK, GREY, SAND, WHITE]


def block(left, top, right, bottom, fill, ring=DARK, size=16):
    """A 16x16 image holding a filled rectangle with a 1 px ring, both inclusive."""
    image = png.blank(size, size)
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            edge = x in (left, right) or y in (top, bottom)
            image.set(x, y, (ring if edge else fill) + (255,))
    return image


def opaque(image):
    return {(x, y) for y in range(image.height) for x in range(image.width) if image.alpha(x, y)}


class BuildTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = pathlib.Path(scratch.name)
        self.packs = self.root / "packs"
        (self.packs / "itch" / "icons").mkdir(parents=True)
        self.fixes = self.root / "fixes"
        self.fixes.mkdir()
        self.out = self.root / "art" / "items"
        # A log 15 px wide, as Kyrise's wood_01a is, and a coil on the cell's bottom row.
        png.write_png(self.packs / "itch" / "icons" / "log.png", block(1, 2, 15, 12, BROWN))
        sheet = png.blank(32, 16)
        sheet.paste(block(2, 4, 13, 15, BROWN), 16, 0)
        png.write_png(self.packs / "itch" / "icons" / "tools.png", sheet)
        png.write_png(self.fixes / "nut.png", block(3, 3, 12, 12, SAND, ring=BLACK))

    def recipe(self, **extra):
        icons = [
            {"id": "log", "from": "icons", "file": "log.png", "erase_columns": [15], "map": {"#9b6742": "#9badb7"}},
            {"id": "coil", "from": "icons", "file": "tools.png", "cell": [1, 0], "shift": [0, -1]},
            {"id": "nut", "hand": "nut.png"},
        ]
        recipe = {"sources": {"icons": "itch/icons"}, "outline": "#000000", "icons": icons}
        recipe.update(extra)
        return recipe

    def build(self, recipe=None):
        return items.build(recipe or self.recipe(), self.packs, self.fixes, self.out, PALETTE, log=lambda _line: None)

    def test_icons_are_cut_recoloured_trimmed_shifted_and_outlined(self):
        icons = self.build()
        self.assertEqual(sorted(icons), ["coil", "log", "nut"])
        log = png.read_png(self.out / "log.png")
        self.assertEqual(items.opaque_box(log), (1, 2, 14, 12), "trimmed to 14 px wide")
        self.assertEqual(log.get(5, 5)[:3], GREY, "the map recolours")
        self.assertEqual(log.get(14, 5)[:3], BLACK, "the cut edge is outlined again")
        self.assertEqual(log.get(1, 5)[:3], BLACK, "the pack's ring becomes the recipe's outline")
        coil = png.read_png(self.out / "coil.png")
        self.assertEqual(items.opaque_box(coil), (2, 3, 13, 14), "moved up off the bottom row")
        self.assertEqual(coil.get(5, 6)[:3], SAND, "an off-palette colour takes the nearest palette colour")
        self.assertEqual(png.read_png(self.out / "nut.png"), png.read_png(self.fixes / "nut.png"))

    def test_a_hand_fix_overlay_is_blended_last(self):
        fix = png.blank(16, 16)
        fix.set(5, 5, WHITE + (255,))
        fix.set(1, 5, (0xFF, 0x00, 0xFF, 255))
        png.write_png(self.fixes / "log.png", fix)
        log = self.build()["log"]
        self.assertEqual(log.get(5, 5)[:3], WHITE)
        self.assertEqual(log.get(1, 5)[3], 0, "#ff00ff erases")
        self.assertEqual(log.get(2, 5)[:3], BLACK, "the outline closes round the erased pixel")

    def test_running_twice_gives_the_same_bytes(self):
        self.build()
        first = {path.name: path.read_bytes() for path in self.out.iterdir()}
        self.build()
        self.assertEqual(first, {path.name: path.read_bytes() for path in self.out.iterdir()})

    def test_an_icon_outside_the_box_is_refused_and_nothing_is_written(self):
        recipe = self.recipe()
        del recipe["icons"][0]["erase_columns"]
        with self.assertRaisesRegex(items.ItemError, r"log: spans \(1, 2, 15, 12\), outside the 14x14 box"):
            self.build(recipe)
        self.assertFalse(self.out.exists())

    def test_two_icons_with_one_silhouette_are_refused_naming_both(self):
        png.write_png(self.fixes / "twin.png", block(3, 3, 12, 12, GREY, ring=BLACK))
        recipe = self.recipe()
        recipe["icons"].append({"id": "twin", "hand": "twin.png"})
        with self.assertRaisesRegex(items.ItemError, "nut and twin share one silhouette"):
            self.build(recipe)
        self.assertFalse(self.out.exists())

    def test_an_off_palette_hand_source_is_remapped(self):
        png.write_png(self.fixes / "nut.png", block(3, 3, 12, 12, (0xDA, 0xA1, 0x65), ring=BLACK))
        self.assertEqual(self.build()["nut"].get(6, 6)[:3], SAND)

    def test_a_shift_off_the_icon_is_refused(self):
        recipe = self.recipe()
        recipe["icons"][1]["shift"] = [0, 1]
        with self.assertRaisesRegex(items.ItemError, "coil: the shift moves"):
            self.build(recipe)

    def test_sources_stay_under_the_packs_root(self):
        recipe = self.recipe(sources={"icons": "../fixes"})
        with self.assertRaisesRegex(items.ItemError, "outside the packs root"):
            self.build(recipe)
        recipe = self.recipe()
        recipe["icons"][0]["file"] = "../log.png"
        with self.assertRaisesRegex(items.ItemError, "not a plain PNG file name"):
            self.build(recipe)

    def test_nothing_is_written_inside_a_download_folder(self):
        with self.assertRaisesRegex(items.ItemError, "inside the download folder itch/"):
            items.build(self.recipe(), self.packs, self.fixes, self.packs / "itch" / "out", PALETTE, log=lambda _line: None)

    def test_an_outline_outside_the_palette_is_refused(self):
        with self.assertRaisesRegex(items.ItemError, "not in the master palette"):
            self.build(self.recipe(outline="#123456"))

    def test_icon_problems_name_an_open_edge_and_half_alpha(self):
        image = block(3, 3, 12, 12, SAND, ring=BLACK)
        image.set(3, 6, SAND + (255,))
        image.set(6, 6, SAND + (128,))
        problems = items.icon_problems(image, "nut", PALETTE, BLACK)
        self.assertIn("nut: an edge pixel at (3, 6) is not the outline colour", problems)
        self.assertIn("nut: a half-transparent pixel at (6, 6)", problems)


class TrackedRecipeTests(unittest.TestCase):
    def test_the_recipe_names_every_item_and_its_hand_sources(self):
        # The 14 items of art-pass and the 4 secret items of secret-cay.
        recipe = items.load_recipe()
        ids = [entry["id"] for entry in recipe["icons"]]
        self.assertEqual(len(ids), 18)
        self.assertEqual(len(set(ids)), 18)
        for entry in recipe["icons"]:
            if "hand" in entry:
                self.assertTrue((items.DEFAULT_FIXES / entry["hand"]).is_file(), entry["hand"])
        game_items = pathlib.Path(items.palette.GAME) / "resources" / "items"
        self.assertEqual(sorted(ids), sorted(path.stem for path in game_items.glob("*.tres")))

    def test_the_hand_sources_are_whole_icons_in_the_palette(self):
        colours = items.palette.load_palette()
        for path in sorted(items.DEFAULT_FIXES.glob("*.png")):
            image = png.read_png(path)
            self.assertEqual(items.icon_problems(image, path.stem, colours, BLACK), [], path.name)


if __name__ == "__main__":
    unittest.main()
