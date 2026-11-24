"""Tests for fx.py, the small effect sprites drawn from palette colours (openspec change
art-sprite-polish D1, D8): the swim ring, and the real recipe's pieces pixel by pixel.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import pathlib
import tempfile
import unittest

import fx
import palette
import png

WHITE = png.parse_colour("#ffffff")
PALE = png.parse_colour("#cbdbfc")


class LyingShadowTest(unittest.TestCase):
    """art-sprite-polish D8: the lying body's shadow, a soft 23x5 ellipse in MetroCity's colour and alpha."""

    def test_the_lying_shadow_is_a_soft_mirrored_ellipse_that_fills_its_box(self):
        image = fx.build(fx.load_recipe(), palette.load_palette())["shadows/shadow_23x5"]
        self.assertTrue(22 <= image.width <= 24 and image.height == 5, f"{image.width}x{image.height}")
        texels = {image.get(x, y) for y in range(image.height) for x in range(image.width)}
        self.assertEqual(texels, {(0, 0, 0, 0), (0, 0, 0, 78)}, "MetroCity's black at alpha 78")
        self.assertTrue(all(image.alpha(x, 2) for x in (0, image.width - 1)), "it reaches both ends")
        self.assertTrue(any(image.alpha(x, 0) for x in range(image.width)) and any(image.alpha(x, 4) for x in range(image.width)))
        for y in range(image.height):
            row = [image.alpha(x, y) for x in range(image.width)]
            self.assertEqual(row, row[::-1], f"row {y} mirrored left to right")

    def test_the_tracked_lying_shadow_is_the_recipes(self):
        tracked = png.read_png(palette.ART / "shadows" / "shadow_23x5.png")
        self.assertEqual(tracked, fx.build(fx.load_recipe(), palette.load_palette())["shadows/shadow_23x5"])


class WideShadowTest(unittest.TestCase):
    """art-terrain-polish D3 (C14): the raft's shadow on the sand, a soft 30x11 ellipse in the same colour and alpha."""

    def test_the_wide_shadow_is_a_soft_mirrored_ellipse_that_fills_its_box(self):
        image = fx.build(fx.load_recipe(), palette.load_palette())["shadows/shadow_30x11"]
        self.assertEqual((image.width, image.height), (30, 11))
        texels = {image.get(x, y) for y in range(image.height) for x in range(image.width)}
        self.assertEqual(texels, {(0, 0, 0, 0), (0, 0, 0, 78)}, "MetroCity's black at alpha 78")
        self.assertTrue(all(image.alpha(x, 5) for x in (0, image.width - 1)), "it reaches both ends")
        self.assertTrue(any(image.alpha(x, 0) for x in range(image.width)) and any(image.alpha(x, 10) for x in range(image.width)))
        for y in range(image.height):
            row = [image.alpha(x, y) for x in range(image.width)]
            self.assertEqual(row, row[::-1], f"row {y} mirrored left to right")

    def test_the_tracked_wide_shadow_is_the_recipes(self):
        tracked = png.read_png(palette.ART / "shadows" / "shadow_30x11.png")
        self.assertEqual(tracked, fx.build(fx.load_recipe(), palette.load_palette())["shadows/shadow_30x11"])


class SwimRingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe = fx.load_recipe()
        cls.images = fx.build(cls.recipe, palette.load_palette())

    def frames(self):
        ring = self.images["fx/swim_ring"]
        piece = {p["name"]: p for p in self.recipe["pieces"]}["swim_ring"]
        w, h = piece["size"]
        return [ring.crop(i * w, 0, w, h) for i in range(ring.width // w)], (w, h)

    def test_the_ring_is_three_frames_of_about_20x5(self):
        frames, (w, h) = self.frames()
        self.assertEqual(len(frames), 3)
        self.assertTrue(18 <= w <= 22 and 4 <= h <= 6, f"{w}x{h}")
        self.assertEqual(self.images["fx/swim_ring"].height, h)

    def test_the_ring_is_white_and_pale_blue_with_whole_alpha(self):
        frames, _size = self.frames()
        for index, frame in enumerate(frames):
            colours = frame.colours()
            self.assertTrue(colours, f"frame {index} is drawn")
            self.assertLessEqual(colours, {WHITE, PALE}, f"frame {index}")
            self.assertEqual({frame.alpha(x, y) for y in range(frame.height) for x in range(frame.width)} - {0, 255}, set())

    def test_the_ring_is_a_dashed_oval_whose_dashes_move_frame_to_frame(self):
        frames, (w, h) = self.frames()
        for index, frame in enumerate(frames):
            self.assertTrue(any(frame.alpha(x, y) for x in (0, 1) for y in range(h)), f"frame {index} reaches the left end")
            self.assertTrue(any(frame.alpha(x, y) for x in (w - 2, w - 1) for y in range(h)), f"frame {index} reaches the right end")
            drawn = {(x, y) for y in range(h) for x in range(w) if frame.alpha(x, y)}
            self.assertLessEqual(drawn, set(fx.oval_outline(w, h)), f"frame {index} is only the oval's 1 px edge, open inside")
        self.assertEqual(len({bytes(f.pixels) for f in frames}), 3, "each frame shifts the dashes")
        drawn = sum(1 for y in range(h) for x in range(w) if frames[0].alpha(x, y))
        outline = len(fx.oval_outline(w, h))
        self.assertLess(drawn, outline, "dashed: some of the oval is left out")

    def test_two_runs_write_the_same_bytes_and_only_into_the_out_folder(self):
        with tempfile.TemporaryDirectory() as root:
            out = pathlib.Path(root) / "a"
            again = pathlib.Path(root) / "b"
            self.assertEqual(fx.main(["--out", str(out)]), 0)
            self.assertEqual(fx.main(["--out", str(again)]), 0)
            names = sorted(str(p.relative_to(out)).replace("\\", "/") for p in out.rglob("*.png"))
            self.assertEqual(names, sorted(str(p.relative_to(again)).replace("\\", "/") for p in again.rglob("*.png")))
            self.assertIn("fx/swim_ring.png", names)
            for name in names:
                self.assertEqual((out / name).read_bytes(), (again / name).read_bytes(), name)
            self.assertEqual(sorted(p.name for p in pathlib.Path(root).iterdir()), ["a", "b"], "nothing outside the out folders")

    def test_a_colour_off_the_palette_is_refused(self):
        recipe = {"pieces": [{"name": "bad", "folder": "fx", "kind": "ring", "size": [20, 5], "frames": 3, "front": "#123456", "back": "#cbdbfc", "dash": 3, "gap": 1}]}
        with self.assertRaisesRegex(fx.FxError, "#123456"):
            fx.build(recipe, palette.load_palette())

    def test_the_tracked_ring_is_the_recipes(self):
        tracked = png.read_png(palette.ART / "fx" / "swim_ring.png")
        self.assertEqual(tracked, self.images["fx/swim_ring"], "rebuild with python -I tools/art/fx.py")

    def test_a_piece_outside_the_known_folders_is_refused(self):
        recipe = {"pieces": [{"name": "ring", "folder": "../out", "kind": "ring", "size": [20, 5], "frames": 3, "front": "#ffffff", "back": "#cbdbfc", "dash": 2, "gap": 1}]}
        with self.assertRaisesRegex(fx.FxError, "folder"):
            fx.build(recipe, palette.load_palette())


if __name__ == "__main__":
    unittest.main()
