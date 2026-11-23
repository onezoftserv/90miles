"""Tests for mood.py, the squall and open-sea art read from hand sources (openspec change
art-mood-pass D9): each rule on fixtures, then the tracked sources and their built files.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import pathlib
import tempfile
import unittest

import mood
import palette
import png

PALE = png.parse_colour("#cbdbfc")
GREY = png.parse_colour("#9badb7")
DEEP = png.parse_colour("#306082")
WHITE = png.parse_colour("#ffffff")
INK = png.parse_colour("#222034")
WOOD = png.parse_colour("#8f563b")
OFF = (0x12, 0x34, 0x56)


def streaks(width, height, starts, length):
    """A frame of 1 px streaks running down and to the left from each start, wrapped round the frame."""
    image = png.blank(width, height)
    for x, y in starts:
        for i in range(length):
            image.set((x - i) % width, (y + i) % height, PALE + (255,))
    return image


def plank(outline=INK):
    image = png.blank(16, 5)
    for y in range(5):
        for x in range(16):
            edge = x in (0, 15) or y in (0, 4)
            image.set(x, y, (outline if edge else WOOD) + (255,))
    return image


class RuleTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.fixes = pathlib.Path(scratch.name) / "fixes"
        self.fixes.mkdir()
        self.out = pathlib.Path(scratch.name) / "art"
        self.allowed = palette.load_palette()

    def piece(self, image, **rules):
        png.write_png(self.fixes / "piece.png", image)
        return {"source": "piece.png", "to": "fx/piece.png", "frame": [image.width, image.height], "frames": 1, **rules}

    def build(self, *pieces):
        return mood.build({"pieces": list(pieces)}, self.fixes, self.allowed)

    def test_an_off_palette_pixel_or_a_half_transparent_one_is_refused(self):
        image = streaks(8, 8, [(4, 0)], 3)
        image.set(0, 7, OFF + (255,))
        with self.assertRaisesRegex(mood.MoodError, r"not in the master palette"):
            self.build(self.piece(image))
        image = streaks(8, 8, [(4, 0)], 3)
        image.set(0, 7, PALE + (128,))
        with self.assertRaisesRegex(mood.MoodError, r"half transparent"):
            self.build(self.piece(image))

    def test_a_rain_tile_must_be_seamless_and_under_its_cover(self):
        whole = streaks(16, 16, [(2, 12)], 6)  # crosses the bottom and the left edge, wrapped
        self.build(self.piece(whole, seamless=True, cover=[0.1]))
        cut = png.blank(16, 16)
        for i in range(6):
            cut.set(2 - i if 2 - i >= 0 else 0, 12 + i if 12 + i < 16 else 15, PALE + (255,))
        with self.assertRaisesRegex(mood.MoodError, r"seam"):
            self.build(self.piece(cut, seamless=True))
        heavy = streaks(16, 16, [(x, 0) for x in range(0, 16, 2)], 16)
        with self.assertRaisesRegex(mood.MoodError, r"covers"):
            self.build(self.piece(heavy, seamless=True, cover=[0.25]))

    def test_a_crest_in_white_or_pale_is_refused(self):
        crest = png.blank(8, 3)
        for x in range(2, 6):
            crest.set(x, 1, DEEP + (255,))
        colours = ["#2a5578", "#306082", "#35678a", "#3a6f92", "#4a85a8"]
        self.build(self.piece(crest, colours=colours))
        for bad in (WHITE, PALE):
            crest.set(3, 1, bad + (255,))
            with self.assertRaisesRegex(mood.MoodError, r"not one of its colours"):
                self.build(self.piece(crest, colours=colours))

    def test_a_plank_needs_a_closed_outline(self):
        self.build(self.piece(plank(), outline="#222034"))
        broken = plank()
        broken.set(7, 0, WOOD + (255,))
        with self.assertRaisesRegex(mood.MoodError, r"outline"):
            self.build(self.piece(broken, outline="#222034"))

    def test_a_frame_grid_of_the_wrong_size_is_refused(self):
        image = png.blank(10, 3)
        image.set(1, 1, PALE + (255,))
        piece = self.piece(image)
        piece["frame"], piece["frames"] = [5, 3], 3
        with self.assertRaisesRegex(mood.MoodError, r"not 3 frames of 5x3"):
            self.build(piece)

    def test_a_refused_source_writes_nothing(self):
        good = self.piece(plank(), outline="#222034")
        bad = dict(good, to="fx/other.png")
        broken = plank()
        broken.set(7, 0, WOOD + (255,))
        png.write_png(self.fixes / "other.png", broken)
        bad["source"] = "other.png"
        code = mood.main(["--recipe", str(self.write_recipe([good, bad])), "--fixes", str(self.fixes), "--out", str(self.out)])
        self.assertEqual(code, 1)
        self.assertFalse(self.out.exists() and any(self.out.rglob("*.png")), "nothing written")

    def write_recipe(self, pieces):
        import json
        path = self.fixes.parent / "recipe.json"
        path.write_text(json.dumps({"pieces": pieces}), encoding="utf-8")
        return path

    def test_it_reads_only_the_fixes_folder_and_a_rerun_gives_the_same_bytes(self):
        read = []
        real = png.read_png

        def spy(path):
            read.append(pathlib.Path(path).resolve())
            return real(path)

        png.read_png = spy
        try:
            recipe = self.write_recipe([self.piece(plank(), outline="#222034")])
            self.assertEqual(mood.main(["--recipe", str(recipe), "--fixes", str(self.fixes), "--out", str(self.out)]), 0)
        finally:
            png.read_png = real
        sources = [path for path in read if path != palette.MASTER_PALETTE.resolve()]
        self.assertTrue(sources and all(path.parent == self.fixes.resolve() for path in sources), "only the fixes folder (and the palette); no pack folder is read")
        first = (self.out / "fx" / "piece.png").read_bytes()
        self.assertEqual(mood.main(["--recipe", str(recipe), "--fixes", str(self.fixes), "--out", str(self.out)]), 0)
        self.assertEqual((self.out / "fx" / "piece.png").read_bytes(), first)


class TrackedTests(unittest.TestCase):
    """The tracked hand sources pass every rule, and the built files are them, byte for byte."""

    def test_the_tracked_sources_build_and_match_the_tracked_art(self):
        images = mood.build(mood.load_recipe(), mood.DEFAULT_FIXES, palette.load_palette())
        # The crests, the wake and the plank join with the crossing's nodes (group 5); check.py refuses
        # tracked art that no scene draws.
        self.assertEqual(sorted(images), ["fx/rain.png", "fx/splash.png"])
        for target, image in images.items():
            self.assertEqual(png.read_png(palette.ART / target), image, f"{target} is the recipe's")

    def test_the_rain_has_a_light_and_a_heavy_stage(self):
        rain = png.read_png(palette.ART / "fx" / "rain.png")
        light, heavy = rain.crop(0, 0, 64, 64), rain.crop(64, 0, 64, 64)
        shares = [sum(1 for a in frame.pixels[3::4] if a) / 4096 for frame in (light, heavy)]
        self.assertTrue(0 < shares[0] <= 0.12 < shares[1] <= 0.25, f"light {shares[0]:.0%}, heavy {shares[1]:.0%}")


if __name__ == "__main__":
    unittest.main()
