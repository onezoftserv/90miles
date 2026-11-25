"""Tests for raft_fittings.py (island-stop task 3.6): the overlay sheet is three 64x32 cells in the
fittings' order, drawn only in master palette colours, each cell holding something, and the tracked
sheet is what the script draws.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import unittest

import palette
import png
import raft_fittings


class RaftFittingsTest(unittest.TestCase):
    def setUp(self):
        self.sheet = raft_fittings.sheet()

    def test_three_cells_the_raft_frame_size(self):
        self.assertEqual((self.sheet.width, self.sheet.height), (64 * 3, 32))
        self.assertEqual(raft_fittings.ORDER, ("raft_clavazon", "raft_defensas", "raft_toldo"))

    def test_only_master_palette_colours(self):
        allowed = {tuple(c[:3]) for c in palette.load_palette()}
        pixels = self.sheet.pixels
        for i in range(0, len(pixels), 4):
            if pixels[i + 3]:
                self.assertIn(tuple(pixels[i:i + 3]), allowed)

    def test_every_cell_draws_something(self):
        for cell in range(3):
            drawn = 0
            for y in range(32):
                for x in range(cell * 64, cell * 64 + 64):
                    drawn += self.sheet.pixels[(y * self.sheet.width + x) * 4 + 3] > 0
            self.assertGreater(drawn, 10, f"cell {cell}")

    def test_the_tracked_sheet_is_up_to_date(self):
        tracked = png.read_png(raft_fittings.OUT)
        self.assertEqual(bytes(tracked.pixels), bytes(self.sheet.pixels))


if __name__ == "__main__":
    unittest.main()
