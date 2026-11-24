"""Tests for ui.py, the HUD window kit builder (openspec change hud-window-kit, D2): the real recipe's
pieces pixel by pixel, and the ramp and digits kinds on fixture recipes.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import json
import pathlib
import tempfile
import unittest

import palette
import png
import ui

T = (0, 0, 0, 0)


def rgba(text):
    return png.parse_colour(text) + (255,)


class UiBase(unittest.TestCase):
    def build_real(self):
        recipe = ui.load_recipe()
        return {p["name"]: p for p in recipe["pieces"]}, ui.build(recipe, palette.load_palette())

    def run_cli(self, recipe, out):
        path = pathlib.Path(out).parent / "recipe.json"
        path.write_text(json.dumps(recipe), encoding="utf-8")
        return ui.main(["--recipe", str(path), "--out", str(out)])


class RealKit(UiBase):
    @classmethod
    def setUpClass(cls):
        recipe = ui.load_recipe()
        cls.pieces = {p["name"]: p for p in recipe["pieces"]}
        cls.images = ui.build(recipe, palette.load_palette())

    def test_sizes(self):
        sizes = {
            "window_dark": (10, 10), "window_thin": (6, 6), "tab_dark": (10, 10), "window_paper": (10, 10),
            "panel_paper": (10, 10), "slot_well": (8, 8), "slot_selected": (8, 8), "button": (10, 10),
            "button_hover": (10, 10), "button_pressed": (10, 10), "focus_ring": (6, 6), "line_edit": (8, 8),
            "scroll_track": (6, 6), "scroll_grabber": (6, 8), "check_off": (9, 9), "check_on": (9, 9),
            "arrow_down": (7, 4), "radio_off": (7, 7), "radio_on": (7, 7),
            "clock_moon": (5, 5), "clock_sun": (5, 5), "status_bleeding": (7, 7), "status_sunstroke": (7, 7),
            "arrow_straight": (9, 9), "arrow_diagonal": (9, 9),
            "ramp_health": (1, 5), "ramp_thirst": (1, 5), "ramp_hunger": (1, 5), "ramp_heat": (1, 5),
            "ramp_energy": (1, 5), "ramp_morale": (1, 5), "digits_3x5": (60, 14),
        }
        self.assertEqual(set(sizes), set(self.images))
        for name, size in sizes.items():
            self.assertEqual((self.images[name].width, self.images[name].height), size, name)

    def test_outer_corners_transparent(self):
        for name, image in self.images.items():
            if name in ("arrow_down", "digits_3x5") or name.startswith("ramp_"):
                continue
            w, h = image.width, image.height
            corners = [(0, 0), (w - 1, 0)] + ([] if name == "tab_dark" else [(0, h - 1), (w - 1, h - 1)])
            for x, y in corners:
                self.assertEqual(image.alpha(x, y), 0, f"{name} ({x},{y})")

    def test_every_pixel_is_palette_and_whole_alpha(self):
        allowed = set(palette.load_palette())
        for name, image in self.images.items():
            for y in range(image.height):
                for x in range(image.width):
                    pixel = image.get(x, y)
                    self.assertIn(pixel[3], (0, 255), name)
                    if pixel[3]:
                        self.assertIn(pixel[:3], allowed, f"{name} ({x},{y})")

    def check_window(self, name, o, light, dark, fill):
        image = self.images[name]
        w, h = image.width, image.height
        o, light, dark, fill = map(rgba, (o, light, dark, fill))
        for x in range(1, w - 1):
            self.assertEqual(image.get(x, 0), o)
            self.assertEqual(image.get(x, h - 1), o)
        for y in range(1, h - 1):
            self.assertEqual(image.get(0, y), o)
            self.assertEqual(image.get(w - 1, y), o)
        for x, y in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
            self.assertEqual(image.get(x, y), o, f"{name} diagonal ({x},{y})")
        for x in range(2, w - 2):
            self.assertEqual(image.get(x, 1), light)
        for y in range(2, h - 2):
            self.assertEqual(image.get(1, y), light)
            self.assertEqual(image.get(w - 2, y), dark)
        for x in range(2, w - 2):
            self.assertEqual(image.get(x, h - 2), dark)
        for y in range(2, h - 2):
            for x in range(2, w - 2):
                self.assertEqual(image.get(x, y), fill, f"{name} ({x},{y})")

    def test_windows(self):
        self.check_window("window_dark", "#222034", "#d9a066", "#8f563b", "#222034")
        self.check_window("window_paper", "#222034", "#ffffff", "#e4b488", "#ffedde")
        self.check_window("panel_paper", "#663931", "#f6dcb4", "#c08a5a", "#eec39a")
        self.check_window("slot_well", "#222034", "#696a6a", "#9badb7", "#847e87")
        self.check_window("button", "#222034", "#639bff", "#3f3f74", "#306082")
        self.check_window("button_hover", "#222034", "#cbdbfc", "#3f3f74", "#306082")
        self.check_window("button_pressed", "#222034", "#3f3f74", "#639bff", "#3f3f74")
        self.check_window("line_edit", "#222034", "#c08a5a", "#ffedde", "#ffedde")
        self.check_window("scroll_track", "#222034", "#3f3f74", "#3f3f74", "#3f3f74")
        self.check_window("scroll_grabber", "#222034", "#eec39a", "#8f563b", "#d9a066")

    def test_bevel_colours_on_each_side(self):
        image = self.images["window_dark"]
        self.assertEqual(image.get(4, 1), rgba("#d9a066"))
        self.assertEqual(image.get(1, 4), rgba("#d9a066"))
        self.assertEqual(image.get(4, 8), rgba("#8f563b"))
        self.assertEqual(image.get(8, 4), rgba("#8f563b"))

    def test_window_thin_is_all_outline(self):
        image = self.images["window_thin"]
        for y in range(6):
            for x in range(6):
                expected = T if (x in (0, 5) and y in (0, 5)) else rgba("#222034")
                self.assertEqual(image.get(x, y), expected, (x, y))

    def test_tab_open_bottom(self):
        image = self.images["tab_dark"]
        window = self.images["window_dark"]
        for y in range(8):
            for x in range(10):
                self.assertEqual(image.get(x, y), window.get(x, y), (x, y))
        o, light, dark, fill = map(rgba, ("#222034", "#d9a066", "#8f563b", "#222034"))
        for y in (8, 9):
            self.assertEqual([image.get(x, y) for x in range(10)], [o, light] + [fill] * 6 + [dark, o])

    def test_slot_selected(self):
        image = self.images["slot_selected"]
        yellow, orange, grey = map(rgba, ("#fbf236", "#df7126", "#847e87"))
        self.assertEqual(image.get(0, 0)[3], 0)
        for x in range(1, 7):
            self.assertEqual(image.get(x, 0), yellow)
        for x, y in ((1, 1), (6, 1), (1, 6), (6, 6)):
            self.assertEqual(image.get(x, y), yellow)
        for x in range(2, 6):
            self.assertEqual(image.get(x, 1), orange)
        for x, y in ((2, 2), (5, 2), (2, 5), (5, 5)):
            self.assertEqual(image.get(x, y), orange)
        for x, y in ((3, 2), (4, 2), (3, 3), (4, 4), (2, 3), (5, 4)):
            self.assertEqual(image.get(x, y), grey)

    def test_focus_ring(self):
        image = self.images["focus_ring"]
        yellow = rgba("#fbf236")
        for y in range(6):
            for x in range(6):
                on = (x, y) in {(1, 1), (4, 1), (1, 4), (4, 4)} or (
                    (x in (0, 5) or y in (0, 5)) and (x, y) not in {(0, 0), (5, 0), (0, 5), (5, 5)})
                self.assertEqual(image.get(x, y), yellow if on else T, (x, y))
        self.assertEqual(image.get(2, 2), T)
        self.assertEqual(image.get(3, 3), T)

    def test_checks(self):
        off, on = self.images["check_off"], self.images["check_on"]
        o, fill = rgba("#222034"), rgba("#ffedde")
        for y in range(9):
            for x in range(9):
                if (x, y) in {(0, 0), (8, 0), (0, 8), (8, 8)}:
                    self.assertEqual(off.get(x, y), T)
                elif x in (0, 8) or y in (0, 8):
                    self.assertEqual(off.get(x, y), o)
                else:
                    self.assertEqual(off.get(x, y), fill)
        differ = [(x, y) for y in range(9) for x in range(9) if off.get(x, y) != on.get(x, y)]
        self.assertTrue(len(differ) >= 8)
        for x, y in differ:
            self.assertTrue(1 <= x <= 7 and 1 <= y <= 7)
            self.assertEqual(on.get(x, y), o)

    def test_arrow_and_radios(self):
        arrow = self.images["arrow_down"]
        cream = rgba("#ffedde")
        want = {0: range(0, 7), 1: range(1, 6), 2: range(2, 5), 3: range(3, 4)}
        for y in range(4):
            for x in range(7):
                self.assertEqual(arrow.get(x, y), cream if x in want[y] else T, (x, y))
        off, on = self.images["radio_off"], self.images["radio_on"]
        rows = {0: (2, 3, 4), 1: (1, 5), 2: (0, 6), 3: (0, 6), 4: (0, 6), 5: (1, 5), 6: (2, 3, 4)}
        for y in range(7):
            for x in range(7):
                self.assertEqual(off.get(x, y), cream if x in rows[y] else T, (x, y))
                if 2 <= x <= 4 and 2 <= y <= 4:
                    self.assertEqual(on.get(x, y), rgba("#fbf236"))
                else:
                    self.assertEqual(on.get(x, y), off.get(x, y))


class Kinds(UiBase):
    def test_ramp(self):
        recipe = {"pieces": [{"name": "r", "kind": "ramp", "highlight": "#ffffff", "base": "#222034", "shade": "#000000"}]}
        image = ui.build(recipe, palette.load_palette())["r"]
        self.assertEqual((image.width, image.height), (1, 5))
        self.assertEqual([image.get(0, y)[:3] for y in range(5)],
                         [(255, 255, 255), (0x22, 0x20, 0x34), (0x22, 0x20, 0x34), (0x22, 0x20, 0x34), (0, 0, 0)])

    def test_digits(self):
        recipe = {"pieces": [{"name": "d", "kind": "digits", "colours": ["#ffedde", "#df7126"], "outline": "#222034"}]}
        image = ui.build(recipe, palette.load_palette())["d"]
        self.assertEqual((image.width, image.height), (60, 14))
        outline = rgba("#222034")
        for row, colour in enumerate(("#ffedde", "#df7126")):
            for i, ch in enumerate(ui.GLYPH_ORDER):
                on = set()
                for gy, line in enumerate(ui.GLYPHS[ch]):
                    for gx, c in enumerate(line):
                        if c == "#":
                            on.add((gx + 1, gy + 1))
                for cy in range(7):
                    for cx in range(5):
                        got = image.get(i * 5 + cx, row * 7 + cy)
                        near = any((cx + dx, cy + dy) in on for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                        want = rgba(colour) if (cx, cy) in on else outline if near else T
                        self.assertEqual(got, want, (ch, row, cx, cy))
        self.assertEqual(image.get(1 + 1, 1), rgba("#ffedde"))  # the top of the 0 glyph
        self.assertEqual(image.get(0, 0), outline)  # the outline wraps the glyph's corner

    def test_off_palette_refused_and_nothing_written(self):
        recipe = {"pieces": [
            {"name": "good", "kind": "ramp", "highlight": "#ffffff", "base": "#222034", "shade": "#000000"},
            {"name": "bad", "kind": "ramp", "highlight": "#123456", "base": "#222034", "shade": "#000000"}]}
        with tempfile.TemporaryDirectory() as root:
            out = pathlib.Path(root) / "out"
            self.assertNotEqual(self.run_cli(recipe, out), 0)
            self.assertFalse(out.exists() and any(out.iterdir()))

    def test_the_meter_ramps(self):
        # hud-window-kit design D4: rows highlight, base x3, shade, per meter.
        expected = {"ramp_health": ("#99e550", "#6abe30", "#4b692f"), "ramp_thirst": ("#cbdbfc", "#639bff", "#5b6ee1"),
                    "ramp_hunger": ("#eec39a", "#d9a066", "#8f563b"), "ramp_heat": ("#fbf236", "#df7126", "#ac3232"),
                    "ramp_energy": ("#ffffff", "#fbf236", "#8a6f30"), "ramp_morale": ("#ffedde", "#d77bba", "#76428a")}
        images = ui.build(ui.load_recipe(), palette.load_palette())
        for name, (high, base, shade) in expected.items():
            image = images[name]
            rows = [png.colour_hex(image.get(0, y)[:3]) for y in range(5)]
            self.assertEqual(rows, [high, base, base, base, shade], name)

    def test_two_runs_are_byte_identical(self):
        with tempfile.TemporaryDirectory() as root:
            first, second = pathlib.Path(root) / "a", pathlib.Path(root) / "b"
            for out in (first, second):
                self.assertEqual(ui.main(["--out", str(out)]), 0)
            files = sorted(p.name for p in first.iterdir())
            self.assertEqual(files, sorted(p.name for p in second.iterdir()))
            self.assertEqual(len(files), 32)
            for name in files:
                self.assertEqual((first / name).read_bytes(), (second / name).read_bytes(), name)


if __name__ == "__main__":
    unittest.main()
