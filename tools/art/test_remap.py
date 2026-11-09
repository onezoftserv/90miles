"""Tests for remap.py: to the master palette or a per-part colour map (design.md D7, D8, C1 D7)."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

import png
import remap

HERE = pathlib.Path(__file__).resolve().parent
PALETTE = [(0, 0, 0), (0xD9, 0xA0, 0x66), (0xFF, 0xFF, 0xFF), (0x5E, 0xF0, 0xBC), (0xFF, 0xED, 0xDE)]
KEY = [(0x5E, 0xF0, 0xBC)]


def image_of(*pixels):
    image = png.blank(len(pixels), 1)
    for x, rgba in enumerate(pixels):
        image.set(x, 0, rgba)
    return image


class RemapTest(unittest.TestCase):
    def test_off_palette_colours_go_to_the_nearest_and_the_changes_are_reported(self):
        image = image_of((0xDA, 0xA1, 0x60, 255), (0xD9, 0xA0, 0x66, 255), (0xDA, 0xA1, 0x60, 255))
        out, changes = remap.remap(image, PALETTE)
        self.assertEqual(out.get(0, 0), (0xD9, 0xA0, 0x66, 255))
        self.assertEqual(out.get(1, 0), (0xD9, 0xA0, 0x66, 255))
        self.assertEqual(changes, {("#daa160", "#d9a066"): 2})
        self.assertEqual(image.get(0, 0), (0xDA, 0xA1, 0x60, 255), "the input is not changed")

    def test_a_colour_map_wins_over_the_nearest_colour(self):
        # #fff2ec is nearer the skin highlight than white, so a body part maps it explicitly.
        image = image_of((0xFF, 0xF2, 0xEC, 255))
        nearest, _ = remap.remap(image, PALETTE)
        self.assertEqual(nearest.get(0, 0)[:3], (0xFF, 0xED, 0xDE))
        mapped, changes = remap.remap(image, PALETTE, colour_map={(0xFF, 0xF2, 0xEC): (0xFF, 0xFF, 0xFF)})
        self.assertEqual(mapped.get(0, 0), (0xFF, 0xFF, 0xFF, 255))
        self.assertEqual(changes, {("#fff2ec", "#ffffff"): 1})

    def test_strict_mode_refuses_an_unmapped_colour_and_names_it(self):
        image = image_of((0xFF, 0xF2, 0xEC, 255), (0x12, 0x34, 0x56, 255))
        with self.assertRaises(remap.RemapError) as caught:
            remap.remap(image, PALETTE, colour_map={(0xFF, 0xF2, 0xEC): (0xFF, 0xFF, 0xFF)}, strict=True)
        self.assertIn("#123456", str(caught.exception))

    def test_half_transparent_pixels_are_dropped_outside_shadows_and_decals(self):
        image = image_of((0x10, 0x10, 0x10, 128), (0xD9, 0xA0, 0x66, 255))
        dropped, _ = remap.remap(image, PALETTE)
        self.assertEqual(dropped.alpha(0, 0), 0)
        kept, _ = remap.remap(image, PALETTE, keep_partial_alpha=True)
        self.assertEqual(kept.get(0, 0), (0, 0, 0, 128), "a shadow keeps its alpha in the darkest colour")

    def test_the_key_ramp_is_never_a_nearest_colour(self):
        image = image_of((0x5F, 0xF0, 0xBB, 255))
        out, _ = remap.remap(image, PALETTE, exclude=KEY)
        self.assertNotIn(out.get(0, 0)[:3], KEY)
        mapped, _ = remap.remap(image, PALETTE, colour_map={(0x5F, 0xF0, 0xBB): KEY[0]}, exclude=KEY)
        self.assertEqual(mapped.get(0, 0)[:3], KEY[0], "only a colour map writes a key colour")

    def test_a_colour_map_reads_from_json_text(self):
        self.assertEqual(remap.parse_map({"#FFF2EC": "#ffffff"}), {(0xFF, 0xF2, 0xEC): (0xFF, 0xFF, 0xFF)})


class RemapCommandTest(unittest.TestCase):
    def test_the_command_keeps_partial_alpha_only_for_a_shadow_target(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = pathlib.Path(scratch)
            source = root / "in.png"
            png.write_png(source, image_of((0x10, 0x10, 0x10, 128), (0xDA, 0xA1, 0x60, 255)))
            (root / "shadows").mkdir()
            for target in (root / "out.png", root / "shadows" / "out.png"):
                result = subprocess.run([sys.executable, "-I", str(HERE / "remap.py"), str(source), str(target)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("#daa160 -> #d9a066", result.stdout)
            self.assertEqual(png.read_png(root / "out.png").alpha(0, 0), 0)
            self.assertEqual(png.read_png(root / "shadows" / "out.png").alpha(0, 0), 128)

    def test_the_command_refuses_an_unreadable_png_in_one_line(self):
        with tempfile.TemporaryDirectory() as scratch:
            source = pathlib.Path(scratch) / "broken.png"
            source.write_bytes(png.encode_png(image_of((0, 0, 0, 255)))[:-20])
            target = pathlib.Path(scratch) / "x.png"
            result = subprocess.run([sys.executable, "-I", str(HERE / "remap.py"), str(source), str(target)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)
            self.assertIn("broken.png", result.stderr)
            self.assertIn("not a readable PNG", result.stderr)
            self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
