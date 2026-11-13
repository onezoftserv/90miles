"""Tests for rim.py (art-pass "Outlines": "A piece with its own edge keeps its size", "A hand-made
icon without its rim"; design.md D8 as amended by C1)."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

import palette
import png
import rim

HERE = pathlib.Path(__file__).resolve().parent
OUTLINE_SET = [(0, 0, 0), (0x22, 0x20, 0x34), (0x45, 0x28, 0x3C), (0x32, 0x3C, 0x39)]
SKIN_RING = (0xEE, 0xC3, 0x9A)
GREY_RING = (0x59, 0x56, 0x52)
FILL = (0xD9, 0xA0, 0x66)


def ringed_frame():
    """A 32x32 frame whose 14x29 figure has a light skin and grey edge ring, like MetroCity's."""
    frame = png.blank(32, 32)
    for y in range(2, 31):
        for x in range(9, 23):
            ring = x in (9, 22) or y in (2, 30)
            frame.set(x, y, ((GREY_RING if (x + y) % 3 == 0 else SKIN_RING) if ring else FILL) + (255,))
    return frame


def bbox(image):
    points = [(x, y) for y in range(image.height) for x in range(image.width) if image.alpha(x, y)]
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    return (min(xs), min(ys), max(xs), max(ys))


def edges(image, cell=None):
    width, height = cell or (image.width, image.height)
    found = []
    for y in range(image.height):
        for x in range(image.width):
            if not image.alpha(x, y):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                same_cell = 0 <= nx < image.width and 0 <= ny < image.height and nx // width == x // width and ny // height == y // height
                if not same_cell or not image.alpha(nx, ny):
                    found.append((x, y))
                    break
    return found


class RimTest(unittest.TestCase):
    def test_a_piece_with_its_own_edge_ring_keeps_its_size(self):
        frame = ringed_frame()
        out = rim.rim(frame, OUTLINE_SET)
        self.assertEqual(bbox(out), bbox(frame), "the bounding box does not grow")
        self.assertEqual(bbox(out), (9, 2, 22, 30), "14x29")
        for x, y in edges(out):
            self.assertIn(out.get(x, y)[:3], OUTLINE_SET)
            self.assertEqual(out.get(x, y)[:3], palette.nearest(frame.get(x, y), OUTLINE_SET))

    def test_one_outline_colour_recolours_the_ring_only(self):
        frame = ringed_frame()
        out = rim.rim(frame, OUTLINE_SET, outline=(0, 0, 0))
        ring = set(edges(frame))
        for y in range(32):
            for x in range(32):
                if (x, y) in ring:
                    self.assertEqual(out.get(x, y), (0, 0, 0, 255))
                else:
                    self.assertEqual(out.get(x, y), frame.get(x, y))

    def test_a_rough_icon_gets_a_ring_grown_round_it(self):
        icon = png.blank(16, 16)
        for y in range(4, 12):
            for x in range(4, 12):
                icon.set(x, y, FILL + (255,))
        out = rim.rim(icon, OUTLINE_SET, cell=16, grow=True)
        self.assertEqual(bbox(out), (3, 3, 12, 12))
        for x, y in edges(out):
            self.assertEqual(out.get(x, y)[:3], OUTLINE_SET[0])
        self.assertEqual(out.get(4, 4), FILL + (255,), "the old edge keeps its fill")

    def test_a_ring_grows_only_where_there_is_none(self):
        icon = png.blank(16, 16)
        for y in range(4, 12):
            for x in range(4, 12):
                icon.set(x, y, ((0, 0, 0) if x == 4 else FILL) + (255,))
        out = rim.rim(icon, OUTLINE_SET, cell=16, grow=True)
        self.assertEqual(out.alpha(3, 8), 0, "the dark left side already is a ring")
        self.assertEqual(out.get(12, 8), (0, 0, 0, 255))

    def test_an_overlay_edge_the_body_covers_keeps_its_colour(self):
        body = png.blank(8, 8)
        for y in range(8):
            for x in range(2, 6):
                body.set(x, y, (0, 0, 0, 255))
        overlay = png.blank(8, 8)
        for x in range(1, 7):
            overlay.set(x, 4, (0x5E, 0xF0, 0xBC, 255))
        out = rim.rim(overlay, OUTLINE_SET, over=body, outline=(0, 0, 0))
        self.assertEqual(out.get(3, 4), (0x5E, 0xF0, 0xBC, 255), "open above and below, both covered by the body")
        self.assertEqual(out.get(1, 4), (0, 0, 0, 255), "open where the body is open too")
        self.assertEqual(out.get(6, 4), (0, 0, 0, 255))

    def test_each_cell_is_rimmed_on_its_own(self):
        strip = png.blank(8, 4)
        for y in range(4):
            for x in range(8):
                strip.set(x, y, FILL + (255,))
        out = rim.rim(strip, OUTLINE_SET, cell=4, outline=(0, 0, 0))
        self.assertEqual(out.get(3, 1), (0, 0, 0, 255), "the shared cell border is open")
        self.assertEqual(out.get(4, 1), (0, 0, 0, 255))
        self.assertEqual(out.get(2, 1), FILL + (255,))


class RimCommandTest(unittest.TestCase):
    def test_the_command_rims_a_frame_with_one_outline_colour_without_growing_it(self):
        with tempfile.TemporaryDirectory() as scratch:
            source = pathlib.Path(scratch) / "frame.png"
            target = pathlib.Path(scratch) / "rimmed.png"
            png.write_png(source, ringed_frame())
            result = subprocess.run([sys.executable, "-I", str(HERE / "rim.py"), str(source), str(target), "--outline", "#000000"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            out = png.read_png(target)
            self.assertEqual(bbox(out), (9, 2, 22, 30))
            self.assertEqual({out.get(x, y) for x, y in edges(out)}, {(0, 0, 0, 255)})
            self.assertIn("changed", result.stdout)

    def test_the_command_refuses_a_colour_outside_the_outline_set(self):
        with tempfile.TemporaryDirectory() as scratch:
            source = pathlib.Path(scratch) / "frame.png"
            png.write_png(source, ringed_frame())
            result = subprocess.run([sys.executable, "-I", str(HERE / "rim.py"), str(source), str(pathlib.Path(scratch) / "x.png"), "--outline", "#ff0000"], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("outline set", result.stderr)

    def test_the_command_refuses_a_target_inside_a_pack_folder(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = pathlib.Path(scratch)
            source = root / "frame.png"
            png.write_png(source, ringed_frame())
            (root / "packs" / "kenney").mkdir(parents=True)
            target = root / "packs" / "kenney" / "rimmed.png"
            result = subprocess.run([sys.executable, "-I", str(HERE / "rim.py"), str(source), str(target), "--packs", str(root / "packs")], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)
            self.assertIn("download folder kenney/", result.stderr)
            self.assertFalse(target.exists())

    def test_the_command_refuses_an_unreadable_png_in_one_line(self):
        with tempfile.TemporaryDirectory() as scratch:
            source = pathlib.Path(scratch) / "broken.png"
            source.write_bytes(png.encode_png(ringed_frame())[:-20])
            target = pathlib.Path(scratch) / "x.png"
            result = subprocess.run([sys.executable, "-I", str(HERE / "rim.py"), str(source), str(target)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)
            self.assertIn("broken.png", result.stderr)
            self.assertIn("not a readable PNG", result.stderr)
            self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
