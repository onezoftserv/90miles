"""Tests for portraits.py, the speaker portrait builder of art-guardacostas D10: the shipped portrait
builds at 32x32 in palette colours with whole alpha and a black edge, and matches the tracked PNG;
a fixture source is rimmed in its outline colour; an off-palette or half-transparent source, a
source of the wrong size or outside the fixes, an outline off the outline set and a doubled id are
refused with nothing written; nothing is written inside a download folder; and a second run gives
the same bytes.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import pathlib
import tempfile
import unittest

import palette
import png
import portraits

BLACK = (0, 0, 0)
NAVY = (0x22, 0x20, 0x34)
OLIVE = (0x4B, 0x69, 0x2F)
SKIN = (0xD9, 0xA0, 0x66)
PALETTE = [BLACK, NAVY, OLIVE, SKIN]
OUTLINE = [BLACK, NAVY]
NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def face(size=(8, 8)):
    """A fixture source: a skin block with an olive band and no outline of its own."""
    image = png.blank(*size)
    for y in range(1, size[1] - 1):
        for x in range(1, size[0] - 1):
            image.set(x, y, (OLIVE if y < 3 else SKIN) + (255,))
    return image


def edge_pixels(image):
    """Every opaque pixel with a transparent 4-neighbour or on the image border."""
    for y in range(image.height):
        for x in range(image.width):
            if image.alpha(x, y) and any(
                not (0 <= x + dx < image.width and 0 <= y + dy < image.height) or not image.alpha(x + dx, y + dy)
                for dx, dy in NEIGHBOURS
            ):
                yield x, y


class PortraitArtTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        root = pathlib.Path(self._dir.name)
        self.fixes = root / "fixes"
        self.out = root / "out"
        self.fixes.mkdir()
        png.write_png(self.fixes / "cara.png", face())

    def tearDown(self):
        self._dir.cleanup()

    def recipe(self, **extra):
        entry = {"id": "cara", "hand": "cara.png", "size": [8, 8], "outline": "#000000"}
        entry.update(extra)
        return {"portraits": [entry]}

    def build(self, recipe, fixes=None, out=None):
        return portraits.build(recipe, fixes or self.fixes, out or self.out, PALETTE, OUTLINE, packs=self.out.parent, log=lambda _line: None)

    def assert_refused(self, pattern, recipe):
        with self.assertRaisesRegex(portraits.PortraitArtError, pattern):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing written")

    def test_the_edge_ring_is_rimmed_in_the_outline_colour(self):
        image = self.build(self.recipe())["portraits/cara.png"]
        self.assertEqual((image.width, image.height), (8, 8))
        for x, y in edge_pixels(image):
            self.assertEqual(image.get(x, y), BLACK + (255,), f"edge ({x}, {y})")
        self.assertEqual(image.get(3, 2), OLIVE + (255,), "the band kept")
        self.assertEqual(image.get(3, 4), SKIN + (255,), "the skin kept")
        self.assertEqual(image.get(0, 0)[3], 0, "the background stays transparent")
        self.assertTrue((self.out / "portraits" / "cara.png").is_file())
        navy = self.build(self.recipe(outline="#222034"))["portraits/cara.png"]
        self.assertEqual(navy.get(1, 1), NAVY + (255,), "a portrait's own outline colour")

    def test_an_off_palette_source_is_refused_and_nothing_is_written(self):
        source = face()
        source.set(4, 4, (0x12, 0x34, 0x56, 255))
        png.write_png(self.fixes / "cara.png", source)
        self.assert_refused("#123456", self.recipe())

    def test_an_off_palette_pixel_on_the_edge_is_refused_before_the_rim_hides_it(self):
        source = face()
        source.set(1, 1, (0x12, 0x34, 0x56, 255))
        png.write_png(self.fixes / "cara.png", source)
        self.assert_refused("#123456", self.recipe())

    def test_a_half_transparent_source_is_refused(self):
        source = face()
        source.set(1, 4, SKIN + (128,))
        png.write_png(self.fixes / "cara.png", source)
        self.assert_refused("half-transparent", self.recipe())

    def test_a_source_of_the_wrong_size_missing_or_outside_the_fixes_is_refused(self):
        self.assert_refused("8x8, not 16x16", self.recipe(size=[16, 16]))
        self.assert_refused("no hand-drawn source", self.recipe(hand="nadie.png"))
        self.assert_refused("bare", self.recipe(hand="../cara.png"))
        self.assert_refused("bare", self.recipe(hand="..\\cara.png"))
        png.write_png(self.fixes / "vacia.png", png.blank(8, 8))
        self.assert_refused("empty", self.recipe(hand="vacia.png"))

    def test_a_bad_entry_is_refused(self):
        self.assert_refused("outline colour", self.recipe(outline="#4b692f"))
        self.assert_refused("no \"outline\"", {"portraits": [{"id": "cara", "hand": "cara.png", "size": [8, 8]}]})
        self.assert_refused("unknown key", self.recipe(rim=True))
        self.assert_refused("lower-case", self.recipe(id="Cara"))
        twice = self.recipe()
        twice["portraits"].append(dict(twice["portraits"][0]))
        self.assert_refused("made twice", twice)

    def test_nothing_is_written_inside_a_download_folder(self):
        with self.assertRaisesRegex(portraits.PortraitArtError, "download folder"):
            portraits.build(self.recipe(), self.fixes, self.out / "oga" / "x", PALETTE, OUTLINE, packs=self.out, log=lambda _line: None)
        self.assertFalse(self.out.exists())

    def test_a_second_run_gives_the_same_bytes(self):
        self.build(self.recipe())
        first = (self.out / "portraits" / "cara.png").read_bytes()
        self.build(self.recipe())
        self.assertEqual((self.out / "portraits" / "cara.png").read_bytes(), first)


class ShippedPortraitTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.out = pathlib.Path(self._dir.name) / "out"

    def tearDown(self):
        self._dir.cleanup()

    def build(self):
        return portraits.build(portraits.load_recipe(), portraits.DEFAULT_FIXES, self.out, palette.load_palette(), palette.outline_set(), log=lambda _line: None)

    def test_the_shipped_recipe_is_rodriguez_at_32x32_rimmed_in_black(self):
        # art-guardacostas D10: Rodriguez's 32x32 bust, rimmed #000000, from a tracked hand source.
        entries = portraits.load_recipe()["portraits"]
        self.assertEqual([entry["id"] for entry in entries], ["rodriguez"])
        for entry in entries:
            self.assertEqual(entry["size"], [32, 32], entry["id"])
            self.assertEqual(entry["outline"], "#000000", entry["id"])
            self.assertTrue((portraits.DEFAULT_FIXES / entry["hand"]).is_file(), entry["hand"])

    def test_the_shipped_portrait_builds_in_palette_colours_with_a_black_edge(self):
        image = self.build()["portraits/rodriguez.png"]
        self.assertEqual((image.width, image.height), (32, 32))
        allowed = set(palette.load_palette())
        for y in range(image.height):
            for x in range(image.width):
                pixel = image.get(x, y)
                self.assertIn(pixel[3], (0, 255), f"({x}, {y}) whole alpha")
                if pixel[3]:
                    self.assertIn(pixel[:3], allowed, f"({x}, {y}) in the master palette")
        edges = list(edge_pixels(image))
        self.assertTrue(edges)
        for x, y in edges:
            self.assertEqual(image.get(x, y)[:3], BLACK, f"edge ({x}, {y}) black")

    def test_the_shipped_portrait_builds_the_same_bytes_twice_and_matches_the_tracked_png(self):
        self.build()
        first = (self.out / "portraits" / "rodriguez.png").read_bytes()
        self.build()
        self.assertEqual((self.out / "portraits" / "rodriguez.png").read_bytes(), first)
        self.assertEqual((palette.ART / "portraits" / "rodriguez.png").read_bytes(), first, "run tools/art/portraits.py")


if __name__ == "__main__":
    unittest.main()
