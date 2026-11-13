"""Tests for terrain.py, the terrain art builder of design.md D11 to D13, T13, T14 and K35 to K39,
on a fixture pack written to a scratch folder: key out and recolour, compose the hand tiles from
quadrants, stamp the brush set, lay the sheets out, mask the plain tiles, wrap the foam round the
sand edge and cut the water texture.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import contextlib
import io
import json
import pathlib
import tempfile
import unittest

import png
import terrain

GRASS = (0x10, 0xC0, 0x10)  # off-palette pack colours
BLUE = (0x10, 0x10, 0xC0)
WHITE = (0xFF, 0xFF, 0xFF)
SAND = (0xEE, 0xC3, 0x9A)
ROCK = (0x84, 0x7E, 0x87)
DEEP = (0x30, 0x60, 0x82)
BLACK = (0, 0, 0)
PALETTE = [SAND, ROCK, DEEP, WHITE, BLACK]


def filled(colour, width=16, height=16, rows=None, columns=None):
    """A tile of one colour on the given rows and columns (all of them by default)."""
    image = png.blank(width, height)
    for y in rows if rows is not None else range(height):
        for x in columns if columns is not None else range(width):
            image.set(x, y, colour + (255,))
    return image


def numbered():
    """A stamp with a different colour on each pixel and a transparent one-pixel border."""
    image = png.blank(16, 16)
    for y in range(1, 15):
        for x in range(1, 15):
            image.set(x, y, (x * 16, y * 16, 0, 255))
    return image


def opaque_rows(image):
    return [y for y in range(image.height) if any(image.alpha(x, y) for x in range(image.width))]


def opaque_columns(image):
    return [x for x in range(image.width) if any(image.alpha(x, y) for y in range(image.height))]


class PieceTests(unittest.TestCase):
    def test_cut_takes_one_16_px_tile_and_refuses_one_off_the_sheet(self):
        sheet = png.blank(32, 16)
        sheet.set(16, 0, GRASS + (255,))
        self.assertEqual(terrain.cut(sheet, 1, 0).get(0, 0), GRASS + (255,))
        with self.assertRaisesRegex(terrain.TerrainError, r"tile \(2, 0\)"):
            terrain.cut(sheet, 2, 0, "sand")

    def test_recolour_maps_keys_out_and_drops_partial_alpha(self):
        tile = filled(GRASS)
        tile.set(0, 0, BLUE + (255,))
        tile.set(1, 0, BLACK + (102,))
        out = terrain.recolour(tile, {GRASS: SAND}, {BLUE}, "sand 3")
        self.assertEqual(out.get(5, 5), SAND + (255,))
        self.assertEqual(out.alpha(0, 0), 0)
        self.assertEqual(out.alpha(1, 0), 0)
        self.assertEqual(tile.get(5, 5), GRASS + (255,), "the source tile is not changed")

    def test_recolour_refuses_a_colour_the_recipe_does_not_name(self):
        tile = filled(GRASS)
        tile.set(3, 3, (1, 2, 3, 255))
        with self.assertRaisesRegex(terrain.TerrainError, "sand 3.*#010203"):
            terrain.recolour(tile, {GRASS: SAND}, set(), "sand 3")

    def test_quadrants_takes_each_quarter_from_its_own_tile(self):
        tiles = [filled(c) for c in (SAND, ROCK, DEEP, WHITE)]
        out = terrain.quadrants(*tiles)
        self.assertEqual([out.get(0, 0)[:3], out.get(8, 7)[:3], out.get(7, 8)[:3], out.get(15, 15)[:3]], [SAND, ROCK, DEEP, WHITE])

    def test_stamped_draws_the_centre_stamp_and_a_quarter_stamp_on_each_land_corner(self):
        stamp = numbered()
        self.assertEqual(terrain.stamped(stamp, 0), stamp)
        north_west = terrain.stamped(stamp, terrain.NW)
        self.assertEqual(north_west.get(0, 0), stamp.get(8, 8), "the corner stamp is centred on the corner")
        self.assertEqual(north_west.get(5, 5), stamp.get(5, 5), "the centre stamp is in front of a northern corner")
        self.assertEqual(north_west.alpha(15, 15), 0)
        south_east = terrain.stamped(stamp, terrain.SE)
        self.assertEqual(south_east.get(9, 9), stamp.get(1, 1), "a southern corner stamp is in front of the centre")
        self.assertEqual(terrain.stamped(stamp, 15).get(15, 0), stamp.get(7, 8))

    def test_mirrored_flips_a_tile_left_to_right(self):
        tile = png.blank(16, 16)
        tile.set(0, 3, SAND + (255,))
        self.assertEqual(terrain.mirrored(tile).get(15, 3), SAND + (255,))

    def test_set_sheet_puts_mask_m_at_column_m_mod_4_row_m_div_4_and_the_variants_on_row_4(self):
        tiles = {mask: filled((mask, 0, 0)) for mask in range(16)}
        sheet = terrain.set_sheet(tiles, [filled(WHITE), filled(ROCK)])
        self.assertEqual((sheet.width, sheet.height), (64, 80))
        self.assertEqual(sheet.get(3 * 16, 0)[:3], (3, 0, 0))
        self.assertEqual(sheet.get(2 * 16, 3 * 16)[:3], (14, 0, 0))
        self.assertEqual(sheet.get(0, 64)[:3], WHITE)
        self.assertEqual(sheet.get(16, 64)[:3], ROCK)
        self.assertEqual(sheet.alpha(32, 64), 0)
        self.assertEqual(terrain.sheet_tile(sheet, 14), tiles[14])

    def test_set_sheet_refuses_a_missing_mask(self):
        with self.assertRaisesRegex(terrain.TerrainError, "mask 15"):
            terrain.set_sheet({mask: filled(SAND) for mask in range(15)}, [])

    def test_masked_cuts_a_tile_by_another_tiles_alpha(self):
        out = terrain.masked(filled(ROCK), filled(SAND, rows=range(0, 12)))
        self.assertEqual(out.get(4, 11), ROCK + (255,))
        self.assertEqual(out.alpha(4, 12), 0)


class FoamTests(unittest.TestCase):
    def frame(self):
        """An Eldiran-like frame: land on rows 0 to 5, a foam line on row 6 and a wash on row 5."""
        frame = filled((0x9D, 0x51, 0x2D), rows=range(0, 6))
        for x in range(16):
            frame.set(x, 6, WHITE + (255,))
        for x in range(0, 4):
            frame.set(x, 5, WHITE + (255,))
        return frame

    def test_the_foam_starts_on_the_row_after_the_sand_ends(self):
        sand = filled(SAND, rows=range(0, 12))
        piece = terrain.foam_piece(terrain.shore_field(sand), self.frame(), 6, WHITE, WHITE)
        self.assertEqual(opaque_rows(piece), [11, 12])
        self.assertEqual([x for x in range(16) if piece.alpha(x, 11)], [0, 1, 2, 3], "the wash runs one row up the sand")
        self.assertEqual(piece.get(9, 12), WHITE + (255,))

    def test_the_foam_wraps_round_a_shore_that_faces_east_north_and_west(self):
        field = terrain.shore_field(filled(SAND, columns=range(0, 10)))
        self.assertEqual(opaque_columns(terrain.foam_piece(field, self.frame(), 6, WHITE, WHITE)), [9, 10])
        north = terrain.foam_piece(terrain.shore_field(filled(SAND, rows=range(5, 16))), self.frame(), 6, WHITE, WHITE)
        self.assertEqual(opaque_rows(north), [4, 5])
        west = terrain.foam_piece(terrain.shore_field(filled(SAND, columns=range(4, 16))), self.frame(), 6, WHITE, WHITE)
        self.assertEqual(opaque_columns(west), [3, 4])

    def test_a_tile_with_no_shore_has_no_foam(self):
        self.assertTrue(terrain.foam_piece(terrain.shore_field(filled(SAND)), self.frame(), 6, WHITE, WHITE).is_empty())
        self.assertTrue(terrain.foam_piece(terrain.shore_field(png.blank(16, 16)), self.frame(), 6, WHITE, WHITE).is_empty())

    def test_the_feather_thins_the_foam_from_that_distance_on(self):
        frame = self.frame()
        for y in range(7, 10):
            for x in range(16):
                frame.set(x, y, WHITE + (255,))
        field = terrain.shore_field(filled(SAND, rows=range(0, 12)))
        whole = terrain.foam_piece(field, frame, 6, WHITE, WHITE)
        thin = terrain.foam_piece(field, frame, 6, WHITE, WHITE, feather=4)
        self.assertEqual(sum(1 for x in range(16) if whole.alpha(x, 15)), 16)
        self.assertEqual(sum(1 for x in range(16) if thin.alpha(x, 15)), 8)
        self.assertEqual(sum(1 for x in range(16) if thin.alpha(x, 14)), 16)

    def test_the_fade_colours_the_foam_from_that_distance_on(self):
        frame = self.frame()
        for y in range(7, 10):
            for x in range(16):
                frame.set(x, y, WHITE + (255,))
        field = terrain.shore_field(filled(SAND, rows=range(0, 12)))
        piece = terrain.foam_piece(field, frame, 6, WHITE, WHITE, fade=(3, ROCK))
        self.assertEqual([piece.get(4, y)[:3] for y in (12, 13, 14, 15)], [WHITE, WHITE, ROCK, ROCK])


class ShadeTests(unittest.TestCase):
    def test_a_shade_tile_is_the_shape_in_one_colour_and_softer_at_its_edge(self):
        tile = terrain.shade_tile(filled(SAND, rows=range(0, 12)), BLACK, 60, (20, 40))
        self.assertEqual([tile.get(4, y) for y in (9, 10, 11, 12)], [BLACK + (60,), BLACK + (40,), BLACK + (20,), terrain.CLEAR])

    def test_a_whole_shape_is_shaded_evenly_and_an_empty_one_not_at_all(self):
        whole = terrain.shade_tile(filled(SAND), BLACK, 60, (20, 40))
        self.assertEqual({whole.get(x, y) for x in range(16) for y in range(16)}, {BLACK + (60,)})
        self.assertTrue(terrain.shade_tile(png.blank(16, 16), BLACK, 60, (20, 40)).is_empty())


class ShoreCutTests(unittest.TestCase):
    def edge(self):
        return filled(SAND, rows=range(0, 12))

    def test_a_shore_cut_keeps_a_tile_only_on_the_shape(self):
        edge = self.edge()
        cut = terrain.shore_cut(filled(ROCK), edge, terrain.shore_field(edge))
        self.assertEqual(opaque_rows(cut), list(range(0, 12)))
        self.assertEqual(cut.colours(), {ROCK})

    def test_an_inset_leaves_the_shapes_edge_pixels_bare_and_a_rim_colours_the_cut(self):
        edge = self.edge()
        cut = terrain.shore_cut(filled(ROCK), edge, terrain.shore_field(edge), inset=1, rim=BLACK)
        self.assertEqual(opaque_rows(cut), list(range(0, 11)), "the sand's last row shows")
        self.assertEqual({cut.get(x, 10)[:3] for x in range(16)}, {BLACK})
        self.assertEqual({cut.get(x, 9)[:3] for x in range(16)}, {ROCK})

    def test_a_shore_cut_never_adds_a_pixel_the_tile_does_not_have(self):
        edge = self.edge()
        tile = filled(ROCK, rows=range(4, 16))
        cut = terrain.shore_cut(tile, edge, terrain.shore_field(edge), rim=BLACK)
        self.assertEqual(opaque_rows(cut), list(range(4, 12)))

    def test_a_shore_sheet_holds_own_mask_d_cut_by_sand_mask_s_at_column_s_row_d(self):
        shape = terrain.set_sheet({mask: (filled(SAND) if mask == 15 else self.edge()) for mask in range(16)}, [])
        rows = [[filled(ROCK) for _mask in range(16)], [filled(GRASS) for _mask in range(16)]]
        sheet = terrain.shore_sheet(rows, shape)
        self.assertEqual((sheet.width, sheet.height), (256, 512))
        for s in range(16):
            for d in range(16):
                first = sheet.crop(s * 16, d * 16, 16, 16)
                second = sheet.crop(s * 16, (16 + d) * 16, 16, 16)
                if s == 15 or d & ~s:
                    self.assertTrue(first.is_empty() and second.is_empty(), f"no tile at {s}, {d}")
                else:
                    self.assertEqual(opaque_rows(first), list(range(0, 12)), f"{s}, {d}")
                    self.assertEqual((first.colours(), second.colours()), ({ROCK}, {GRASS}))


class BuildTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = pathlib.Path(scratch.name)
        self.packs = self.root / "packs"
        (self.packs / "oga").mkdir(parents=True)
        self.fixes = self.root / "fixes"
        self.fixes.mkdir()
        self.out = self.root / "art"
        sheet = png.blank(64, 32)
        sheet.paste(filled(GRASS), 0, 0)  # the full tile
        edge = filled(GRASS, rows=range(0, 12))
        for x in range(16):
            edge.set(x, 12, WHITE + (255,))
            edge.set(x, 13, BLUE + (255,))
        sheet.paste(edge, 16, 0)  # an edge tile with a baked foam rim and water strip
        sheet.paste(filled(BLUE, 32, 32), 32, 0)  # the water
        png.write_png(self.packs / "oga" / "world.png", sheet)
        strip = png.blank(1 + 17 * 2, 32)
        frame = filled((0x9D, 0x51, 0x2D), rows=range(0, 6))
        for x in range(16):
            frame.set(x, 6, WHITE + (255,))
        strip.paste(frame, 1, 9)
        strip.paste(frame, 18, 9)
        png.write_png(self.packs / "oga" / "waves.png", strip)

    def recipe(self):
        tiles = {str(mask): [1, 0] for mask in range(1, 15)}
        tiles["15"] = [0, 0]
        hexes = {png.colour_hex(GRASS): png.colour_hex(SAND)}
        erase = [png.colour_hex(WHITE), png.colour_hex(BLUE)]
        return {
            "sources": {"world": "oga/world.png", "waves": "oga/waves.png"},
            "sets": [
                {"id": "sand", "source": "world", "map": hexes, "erase": erase, "tiles": tiles, "quadrants": {"0": [15, 15, 1, 1]}, "variants": ["15", "3h"]},
                {"id": "brush", "source": "world", "map": hexes, "erase": erase, "stamp": [1, 0], "variants": ["0"]},
            ],
            "plain": {"source": "world", "shape": "sand", "rows": [{"id": "rock", "tile": [0, 0], "map": {png.colour_hex(GRASS): png.colour_hex(ROCK)}}]},
            "water": {"source": "world", "rect": [32, 0, 32, 32], "map": {png.colour_hex(BLUE): png.colour_hex(DEEP)}, "ramps": [["#306082"], ["#847e87"]]},
            "foam": {"source": "waves", "shape": "sand", "origin": [1, 9], "step": 17, "frames": 2, "land_rows": 6, "white": "#ffffff", "colour": "#ffffff"},
            "shade": {"shape": "sand", "colour": "#000000", "alpha": 60, "edge": [20, 40], "spots": "spots.png"},
            "copies": [{"from": "pool.png", "to": "terrain/pool.png"}],
        }

    def spots(self):
        """A hand-drawn strip of spot shades: one soft pixel in its first cell."""
        strip = png.blank(64, 16)
        strip.set(5, 5, BLACK + (30,))
        return strip

    def build(self, recipe=None, packs=None, out=None, spots=None):
        png.write_png(self.fixes / "pool.png", filled(ROCK))
        png.write_png(self.fixes / "spots.png", spots or self.spots())
        return terrain.build(recipe or self.recipe(), packs or self.packs, self.fixes, out or self.out, PALETTE, log=lambda _line: None)

    def test_build_writes_every_sheet_at_its_size(self):
        self.build()
        sizes = {}
        for path in sorted(self.out.rglob("*.png")):
            image = png.read_png(path)
            sizes[path.relative_to(self.out).as_posix()] = (image.width, image.height)
        self.assertEqual(sizes, {
            "decals/shade.png": (64, 80), "sea/foam.png": (32, 256), "sea/water.png": (32, 32), "sea/water_ramps.png": (1, 2),
            "terrain/brush.png": (64, 80), "terrain/plain.png": (256, 16), "terrain/pool.png": (16, 16), "terrain/sand.png": (64, 80),
        })

    def test_the_edge_tile_keeps_no_water_or_foam_and_the_foam_meets_it(self):
        self.build()
        sand = png.read_png(self.out / "terrain" / "sand.png")
        edge = terrain.sheet_tile(sand, 3)
        self.assertEqual(edge.colours(), {SAND})
        self.assertEqual(opaque_rows(edge)[-1], 11)
        foam = png.read_png(self.out / "sea" / "foam.png")
        self.assertEqual(opaque_rows(foam.crop(0, 3 * 16, 16, 16)), [12])
        self.assertEqual(opaque_rows(foam.crop(16, 3 * 16, 16, 16)), [12], "frame 1 is the column beside frame 0")
        self.assertTrue(foam.crop(0, 15 * 16, 32, 16).is_empty(), "the full tile has no shore")

    def test_the_quadrant_tile_the_variants_and_the_masked_plain_tiles(self):
        self.build()
        sand = png.read_png(self.out / "terrain" / "sand.png")
        islet = terrain.sheet_tile(sand, 0)
        self.assertEqual((islet.alpha(0, 3), islet.alpha(15, 11), islet.alpha(0, 13)), (255, 255, 0), "the south half is the edge tile's")
        self.assertEqual(sand.crop(0, 64, 16, 16), terrain.sheet_tile(sand, 15))
        self.assertEqual(sand.crop(16, 64, 16, 16), terrain.mirrored(terrain.sheet_tile(sand, 3)))
        plain = png.read_png(self.out / "terrain" / "plain.png")
        self.assertEqual(plain.crop(15 * 16, 0, 16, 16), filled(ROCK), "column 15 is the whole tile")
        self.assertEqual(opaque_rows(plain.crop(3 * 16, 0, 16, 16))[-1], 11, "column m is cut by the sand tile of mask m")
        water = png.read_png(self.out / "sea" / "water.png")
        self.assertEqual(water.colours(), {DEEP})

    def test_a_shore_entry_writes_the_layers_shore_sheet(self):
        recipe = self.recipe()
        recipe["sets"][1]["shore"] = {"shape": "sand", "inset": 1, "rim": "#000000"}
        recipe["plain"]["shore"] = {}
        self.build(recipe)
        brush = png.read_png(self.out / "terrain" / "brush_shore.png")
        self.assertEqual((brush.width, brush.height), (256, 256))
        tile = brush.crop(3 * 16, 0, 16, 16)  # the islet bush on a cell whose sand ends on row 11
        self.assertEqual(opaque_rows(tile)[-1], 10, "one pixel inside the sand's edge")
        self.assertEqual({tile.get(x, 10)[:3] for x in range(16) if tile.alpha(x, 10)}, {BLACK})
        self.assertTrue(brush.crop(15 * 16, 0, 16, 16).is_empty(), "the full sand tile has no shore")
        self.assertTrue(brush.crop(1 * 16, 2 * 16, 16, 16).is_empty(), "mask 2 is not inside mask 1")
        plain = png.read_png(self.out / "terrain" / "plain_shore.png")
        self.assertEqual((plain.width, plain.height), (256, 256))
        self.assertEqual(opaque_rows(plain.crop(3 * 16, 3 * 16, 16, 16)), list(range(0, 12)))

    def test_a_shore_inset_is_a_small_whole_number(self):
        for bad in (-1, 8, "1", 1.5, True):
            recipe = self.recipe()
            recipe["sets"][1]["shore"] = {"shape": "sand", "inset": bad}
            with self.assertRaisesRegex(terrain.TerrainError, r"brush shore: \"inset\""):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_fix_overlay_is_blended_last_and_shapes_the_foam(self):
        fix = png.blank(64, 80)
        for x in range(16):
            fix.set(3 * 16 + x, 11, (0xFF, 0x00, 0xFF, 255))
        png.write_png(self.fixes / "sand.png", fix)
        self.build()
        self.assertEqual(opaque_rows(terrain.sheet_tile(png.read_png(self.out / "terrain" / "sand.png"), 3))[-1], 10)
        self.assertEqual(opaque_rows(png.read_png(self.out / "sea" / "foam.png").crop(0, 48, 16, 16)), [11])

    def overlay(self, *pixels):
        """A 64x80 sand overlay of (x, y, colour) pixels; a colour of None erases."""
        fix = png.blank(64, 80)
        for x, y, rgb in pixels:
            fix.set(x, y, (0xFF, 0x00, 0xFF, 255) if rgb is None else rgb + (255,))
        return fix

    def test_an_overlay_pixel_that_is_already_what_the_tool_builds_is_refused_by_sheet_and_cell(self):
        for pixel in ((5, 5, SAND), (50, 13, None), (20, 40, SAND)):
            png.write_png(self.fixes / "sand.png", self.overlay(pixel))
            cell = (pixel[0] // 16, pixel[1] // 16)
            with self.assertRaisesRegex(terrain.TerrainError, rf"sand\.png.*\({pixel[0]}, {pixel[1]}\).*cell \({cell[0]}, {cell[1]}\)"):
                self.build()
        self.assertFalse(self.out.exists(), "nothing is written")
        png.write_png(self.fixes / "sand.png", self.overlay((5, 5, DEEP), (50, 13, DEEP)))
        self.build()

    def test_a_hand_cell_is_a_blank_tile_the_overlay_must_cover_with_all_256_pixels(self):
        recipe = self.recipe()
        del recipe["sets"][0]["quadrants"]["0"]
        recipe["sets"][0]["tiles"]["0"] = "hand"
        png.write_png(self.fixes / "sand.png", self.overlay((5, 5, SAND)))
        with self.assertRaisesRegex(terrain.TerrainError, r"sand\.png.*hand cell \(0, 0\)"):
            self.build(recipe)
        whole = [(x, y, SAND if (x + y) % 5 else None) for y in range(16) for x in range(16)]
        png.write_png(self.fixes / "sand.png", self.overlay(*whole))
        self.build(recipe)
        islet = terrain.sheet_tile(png.read_png(self.out / "terrain" / "sand.png"), 0)
        self.assertEqual((islet.get(1, 1)[:3], islet.alpha(5, 0)), (SAND, 0), "the hand pixels are the tile, #ff00ff left clear")

    def test_a_map_change_reaches_the_variant_tile_under_the_hand_pixels(self):
        png.write_png(self.fixes / "sand.png", self.overlay((2, 2 + 16 * 4, DEEP)))
        self.build()
        variant = png.read_png(self.out / "terrain" / "sand.png").crop(0, 64, 16, 16)
        self.assertEqual((variant.get(5, 5)[:3], variant.get(2, 2)[:3]), (SAND, DEEP))
        recipe = self.recipe()
        recipe["sets"][0]["map"] = {png.colour_hex(GRASS): png.colour_hex(ROCK)}
        self.build(recipe)
        variant = png.read_png(self.out / "terrain" / "sand.png").crop(0, 64, 16, 16)
        self.assertEqual((variant.get(5, 5)[:3], variant.get(2, 2)[:3]), (ROCK, DEEP), "the recipe drives the variant")

    def test_a_png_in_the_fixes_folder_that_no_step_reads_is_refused_by_name(self):
        for stray in ("plain.png", "water.png", "shade.png", "sand_shore.png", "brush_shore.png", "plain_shore.png", "water_ramps.png", "nothing.png"):
            png.write_png(self.fixes / stray, self.overlay((5, 5, DEEP)))
            with self.assertRaisesRegex(terrain.TerrainError, rf"{stray}: no step of the recipe reads it"):
                self.build()
            (self.fixes / stray).unlink()
        recipe = self.recipe()
        del recipe["foam"]
        png.write_png(self.fixes / "foam.png", png.blank(32, 256))
        with self.assertRaisesRegex(terrain.TerrainError, r"foam\.png: no step of the recipe reads it"):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_every_png_the_recipe_reads_is_accepted_in_the_fixes_folder(self):
        png.write_png(self.fixes / "brush.png", self.overlay((5, 5, DEEP)))
        foam = png.blank(32, 256)
        foam.set(3, 240, WHITE + (255,))
        png.write_png(self.fixes / "foam.png", foam)
        self.build()
        self.assertTrue((self.out / "terrain" / "pool.png").exists())

    def test_a_plain_row_takes_a_rim_colour_on_its_cut_edge_and_the_foam_a_fade_colour(self):
        recipe = self.recipe()
        recipe["plain"]["rows"][0]["rim"] = "#000000"
        recipe["foam"]["fade"] = {"from": 1, "colour": png.colour_hex(ROCK)}
        self.build(recipe)
        plain = png.read_png(self.out / "terrain" / "plain.png")
        edge = plain.crop(3 * 16, 0, 16, 16)
        self.assertEqual((edge.get(4, 11)[:3], edge.get(4, 10)[:3]), (BLACK, ROCK))
        self.assertEqual(plain.crop(15 * 16, 0, 16, 16), filled(ROCK), "the whole tile has no rim")
        self.assertEqual(png.read_png(self.out / "sea" / "foam.png").colours(), {ROCK})

    def test_the_shade_set_follows_the_sand_shape_and_its_last_row_holds_the_spots(self):
        self.build()
        shade = png.read_png(self.out / "decals" / "shade.png")
        edge = terrain.sheet_tile(shade, 3)
        self.assertEqual([edge.get(4, y) for y in (9, 10, 11, 12)], [BLACK + (60,), BLACK + (40,), BLACK + (20,), terrain.CLEAR])
        self.assertEqual(terrain.sheet_tile(shade, 15).get(8, 8), BLACK + (60,))
        self.assertEqual(shade.crop(0, 64, 64, 16), self.spots())

    def test_a_spot_strip_of_another_size_or_colour_is_refused(self):
        with self.assertRaisesRegex(terrain.TerrainError, r"spots\.png.*64x16"):
            self.build(spots=png.blank(32, 16))
        grey = self.spots()
        grey.set(5, 5, ROCK + (30,))
        with self.assertRaisesRegex(terrain.TerrainError, r"decals/shade\.png: a half-transparent pixel"):
            self.build(spots=grey)
        self.assertFalse(self.out.exists(), "nothing at all is written when a sheet is refused")

    def test_a_hand_source_is_a_bare_file_name_in_the_fixes_folder(self):
        outside = self.root / "outside.png"
        png.write_png(outside, filled(DEEP))
        bad_names = ["..\\outside.png", str(outside), "sub/x.png", "../x.png", "Pool.png", "pool.PNG", "pool", ""]
        for bad in bad_names:
            for key in ("copies", "spots"):
                recipe = self.recipe()
                if key == "copies":
                    recipe["copies"][0]["from"] = bad
                else:
                    recipe["shade"]["spots"] = bad
                with self.assertRaisesRegex(terrain.TerrainError, r"a hand-drawn source is a lower-case name ending in \.png", msg=f"{key} {bad!r}"):
                    self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_copy_goes_to_a_folder_and_a_lower_case_png_name(self):
        for bad in ("../x.png", "/x.png", "C:/x.png", "x.png", "a/b/c.png", "terrain\\x.png", "Terrain/x.png", "terrain/x.PNG", "terrain/x", ""):
            recipe = self.recipe()
            recipe["copies"][0]["to"] = bad
            with self.assertRaisesRegex(terrain.TerrainError, r"a copy goes to <folder>/<name>\.png", msg=repr(bad)):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_no_sheet_is_made_twice(self):
        def twice(change):
            recipe = self.recipe()
            change(recipe)
            with self.assertRaisesRegex(terrain.TerrainError, r"made twice"):
                self.build(recipe)
        twice(lambda r: r["sets"].append(dict(r["sets"][0])))
        twice(lambda r: r["sets"].append(dict(r["sets"][1], id="plain")))
        twice(lambda r: r["sets"].append(dict(r["sets"][1], id="sand_shore")) or r["sets"][0].update(shore={"shape": "sand"}))
        twice(lambda r: r["copies"][0].update({"to": "terrain/sand.png"}))
        twice(lambda r: r["copies"][0].update({"to": "terrain/plain.png"}))
        twice(lambda r: r["copies"][0].update({"to": "sea/water.png"}))
        twice(lambda r: r["copies"][0].update({"to": "sea/water_ramps.png"}))
        twice(lambda r: r["copies"][0].update({"to": "sea/foam.png"}))
        twice(lambda r: r["copies"][0].update({"to": "decals/shade.png"}))
        twice(lambda r: r["copies"].append(dict(r["copies"][0])))
        twice(lambda r: r["plain"].update(shore={}) or r["copies"][0].update({"to": "terrain/plain_shore.png"}))
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_nothing_is_written_under_a_download_folder_or_the_fixes_folder(self):
        recipe = self.recipe()
        recipe["copies"][0]["to"] = "oga/made.png"
        with self.assertRaisesRegex(terrain.TerrainError, r"download folder oga/"):
            self.build(recipe, out=self.packs)
        self.assertFalse((self.packs / "oga" / "made.png").exists())
        recipe["copies"][0]["to"] = "fixes/pool.png"
        with self.assertRaisesRegex(terrain.TerrainError, r"the fixes folder"):
            self.build(recipe, out=self.root)
        self.assertEqual((self.fixes / "pool.png").read_bytes(), png.encode_png(filled(ROCK)), "the hand source is not replaced")
        self.assertFalse((self.root / "terrain").exists(), "nothing at all is written")

    def run_main(self, recipe, palette=None, files=None):
        """terrain.main on the fixture with `recipe` written to a file: (exit code, what it printed on stderr)."""
        png.write_png(self.fixes / "pool.png", filled(ROCK))
        png.write_png(self.fixes / "spots.png", self.spots())
        palette_path = palette or self.root / "palette.png"
        if palette is None:
            image = png.blank(len(PALETTE), 1)
            for x, rgb in enumerate(PALETTE):
                image.set(x, 0, rgb + (255,))
            png.write_png(palette_path, image)
        for relative, data in (files or {}).items():
            (self.root / relative).write_bytes(data)
        recipe_path = self.root / "recipe.json"
        recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
        argv = ["--packs", str(self.packs), "--recipe", str(recipe_path), "--fixes", str(self.fixes), "--out", str(self.out),
                "--palette", str(palette_path)]
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors), contextlib.redirect_stdout(io.StringIO()):
            code = terrain.main(argv)
        return code, errors.getvalue()

    def test_a_malformed_recipe_is_refused_naming_its_section_and_key_and_writes_nothing(self):
        def set_(index, **changes):
            return lambda r: r["sets"][index].update(changes)

        def tile_of(index, key, value):
            return lambda r: r["sets"][index]["tiles"].update({key: value})

        def to(section, **changes):
            return lambda r: r[section].update(changes)

        cases = [
            ("mask key text", tile_of(0, "x", [1, 0]), r'sand tiles: "x"'),
            ("mask key 16", tile_of(0, "16", [1, 0]), r'sand tiles: "16"'),
            ("mask key -1", tile_of(0, "-1", [1, 0]), r'sand tiles: "-1"'),
            ("mask key 1.5", tile_of(0, "1.5", [1, 0]), r'sand tiles: "1.5"'),
            ("tiles a list", set_(0, tiles=[]), r'sand: "tiles"'),
            ("tile spec short", tile_of(0, "3", [1]), r'sand mask 3: a tile is'),
            ("tile spec text", tile_of(0, "3", ["a", "b"]), r'sand mask 3: a tile is'),
            ("tile spec number", tile_of(0, "3", 5), r'sand mask 3: a tile is'),
            ("tile spec table", tile_of(0, "3", {"a": 1}), r'sand mask 3: a tile is'),
            ("tile spec bool", tile_of(0, "3", [True, 0]), r'sand mask 3: a tile is'),
            ("tile spec colour", tile_of(0, "3", "oops"), r"sand.*'oops'"),
            ("quadrants a list", set_(0, quadrants=[]), r'sand: "quadrants"'),
            ("quadrants mask 99", set_(0, quadrants={"99": [15, 15, 1, 1]}), r'sand quadrants: "99"'),
            ("quadrants parts three", set_(0, quadrants={"0": [15, 15, 1]}), r'sand quadrants: "0" needs four'),
            ("quadrants parts a number", set_(0, quadrants={"0": 5}), r'sand quadrants: "0" needs four'),
            ("quadrants part text", set_(0, quadrants={"0": [15, "x", 1, 1]}), r'sand quadrants: "x"'),
            ("quadrants part 16", set_(0, quadrants={"0": [15, 16, 1, 1]}), r'sand quadrants: "16"'),
            ("map a list", set_(0, map=[]), r'sand: "map"'),
            ("map colour", set_(0, map={"#10c010": 5}), r"sand"),
            ("erase a number", set_(0, erase=5), r'sand: "erase"'),
            ("erase colour", set_(0, erase=["red"]), r"sand.*'red'"),
            ("variants text", set_(0, variants="15"), r'sand: "variants"'),
            ("variant none", set_(0, variants=[None]), r"sand: variant None"),
            ("stamp short", set_(1, stamp=[1]), r"brush stamp: a tile is"),
            ("stamp number", set_(1, stamp=5), r"brush stamp: a tile is"),
            ("a set not a table", lambda r: r["sets"].append(5), r"a set has no"),
            ("sets a table", lambda r: r.update(sets={}), r'the recipe: "sets"'),
            ("shore text (set)", set_(1, shore="x"), r'brush shore: "shore"'),
            ("shore text (plain)", lambda r: r["plain"].update(shore="x"), r'plain shore: "shore"'),
            ("plain a list", lambda r: r.update(plain=[]), r'the recipe: "plain"'),
            ("plain rows empty", lambda r: r["plain"].update(rows=[]), r'plain: "rows"'),
            ("plain rows text", lambda r: r["plain"].update(rows="x"), r'plain: "rows"'),
            ("plain row not a table", lambda r: r["plain"].update(rows=[5]), r"plain row 0"),
            ("plain tile short", lambda r: r["plain"]["rows"][0].update(tile=[1]), r"plain rock: a tile is"),
            ("plain tile text", lambda r: r["plain"]["rows"][0].update(tile="x"), r"plain rock.*'x'"),
            ("plain map a list", lambda r: r["plain"]["rows"][0].update(map=[]), r'plain rock: "map"'),
            ("water a number", lambda r: r.update(water=5), r'the recipe: "water"'),
            ("water rect short", to("water", rect=[1, 2]), r'water: "rect"'),
            ("water rect text", to("water", rect="x"), r'water: "rect"'),
            ("water rect non-number", to("water", rect=[0, 0, "a", 1]), r'water: "rect"'),
            ("water map a list", to("water", map=[]), r'water: "map"'),
            ("ramps text", to("water", ramps="x"), r"water ramps"),
            ("ramps rows of numbers", to("water", ramps=[5]), r"water ramps"),
            ("ramps empty row", to("water", ramps=[["#306082"], []]), r"water ramps"),
            ("ramps colour", to("water", ramps=[["red"]]), r"water ramps.*'red'"),
            ("foam step text", to("foam", step="a"), r'foam: "step"'),
            ("foam step 0", to("foam", step=0), r'foam: "step"'),
            ("foam frames 0", to("foam", frames=0), r'foam: "frames"'),
            ("foam frames text", to("foam", frames="x"), r'foam: "frames"'),
            ("foam frames float", to("foam", frames=1.5), r'foam: "frames"'),
            ("foam origin short", to("foam", origin=[1]), r'foam: "origin"'),
            ("foam land_rows text", to("foam", land_rows="x"), r'foam: "land_rows"'),
            ("foam fade text", to("foam", fade="x"), r'foam: "fade"'),
            ("foam fade from", to("foam", fade={"from": "a", "colour": "#ffffff"}), r'foam fade: "from"'),
            ("foam no pixel at all", to("foam", white="#123456"), r"foam: no pixel at all"),
            ("foam a list", lambda r: r.update(foam=[]), r'the recipe: "foam"'),
            ("shade alpha text", to("shade", alpha="x"), r'shade: "alpha"'),
            ("shade alpha 0", to("shade", alpha=0), r'shade: "alpha"'),
            ("shade alpha 256", to("shade", alpha=256), r'shade: "alpha"'),
            ("shade edge text", to("shade", edge="x"), r'shade: "edge"'),
            ("shade edge item", to("shade", edge=["a"]), r'shade: "edge"'),
            ("shade edge 0", to("shade", edge=[0]), r'shade: "edge"'),
            ("shade a list", lambda r: r.update(shade=[]), r'the recipe: "shade"'),
            ("copies a table", lambda r: r.update(copies={}), r'the recipe: "copies"'),
            ("a copy not a table", lambda r: r.update(copies=[5]), r"a copy has no"),
        ]
        for label, change, message in cases:
            recipe = self.recipe()
            change(recipe)
            code, printed = self.run_main(recipe)
            self.assertEqual(code, 1, f"{label}: {printed}")
            self.assertRegex(printed, r"^terrain: ", label)
            self.assertRegex(printed, message, label)
            self.assertFalse(self.out.exists(), f"{label}: nothing is written")

    def test_a_missing_palette_and_corrupt_pngs_are_refused_with_their_path(self):
        code, printed = self.run_main(self.recipe(), palette=self.root / "no_palette.png")
        self.assertEqual((code, self.out.exists()), (1, False))
        self.assertIn("no_palette.png", printed)
        for relative, name in (("packs/oga/world.png", "world.png"), ("packs/oga/waves.png", "waves.png"), ("fixes/sand.png", "sand.png"),
                               ("fixes/shade_spots.png", "shade_spots.png"), ("fixes/pool.png", "pool.png")):
            self.setUp()
            recipe = self.recipe()
            recipe["shade"]["spots"] = "shade_spots.png" if name == "shade_spots.png" else "spots.png"
            code, printed = self.run_main(recipe, files={relative: b"not a png at all"})
            self.assertEqual(code, 1, name)
            self.assertIn(name, printed)
            self.assertFalse(self.out.exists(), name)

    def test_a_colour_outside_the_palette_is_refused_by_name(self):
        recipe = self.recipe()
        recipe["water"]["map"] = {png.colour_hex(BLUE): "#123456"}
        with self.assertRaisesRegex(terrain.TerrainError, r"sea/water\.png.*#123456"):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing at all is written when a sheet is refused")

    def test_a_source_outside_the_packs_root_is_refused(self):
        recipe = self.recipe()
        recipe["sources"]["world"] = "../fixes/pool.png"
        with self.assertRaisesRegex(terrain.TerrainError, "outside the packs root"):
            self.build(recipe)

    def test_it_never_writes_inside_a_download_folder(self):
        with self.assertRaisesRegex(terrain.TerrainError, "download folder"):
            self.build(out=self.packs / "oga" / "made")
        self.assertFalse((self.packs / "oga" / "made").exists())

    def test_main_prints_the_error_and_returns_1(self):
        recipe_path = self.root / "recipe.json"
        recipe_path.write_text(json.dumps({"sources": {}, "sets": [{"id": "sand", "source": "nowhere"}]}), encoding="utf-8")
        code = terrain.main(["--packs", str(self.packs), "--recipe", str(recipe_path), "--fixes", str(self.fixes), "--out", str(self.out)])
        self.assertEqual(code, 1)

    def test_the_tracked_recipe_names_only_sources_under_the_download_folders(self):
        recipe = terrain.load_recipe(terrain.DEFAULT_RECIPE)
        self.assertEqual(sorted(recipe["sources"]), ["eldiran", "overworld", "scallywag"])
        for relative in recipe["sources"].values():
            self.assertIn(relative.split("/")[0], terrain.DOWNLOAD_FOLDERS)
        self.assertEqual([entry["id"] for entry in recipe["sets"]], ["sand", "dune", "brush"])
        self.assertEqual(len(recipe["plain"]["rows"]), 9)
        self.assertEqual(recipe["shade"]["shape"], "sand")


    def test_the_tracked_overlays_hold_only_hand_pixels(self):
        recipe = terrain.load_recipe(terrain.DEFAULT_RECIPE)
        for entry in recipe["sets"][:2]:
            overlay = png.read_png(terrain.DEFAULT_FIXES / f"{entry['id']}.png")
            hand = terrain.hand_cells(entry)
            for column in range(terrain.SET_COLUMNS):
                cell = overlay.crop(column * 16, terrain.VARIANT_ROW * 16, 16, 16)
                opaque = sum(1 for alpha in cell.pixels[3::4] if alpha)
                self.assertLess(opaque, 40, f"{entry['id']} variant {column} is mask 15 plus a few hand pixels")
            self.assertEqual(hand, {(0, 0)} if entry["id"] == "dune" else set(), entry["id"])
            self.assertEqual(sum(1 for alpha in overlay.crop(0, 0, 16, 16).pixels[3::4] if alpha), 256 if hand else 0)


if __name__ == "__main__":
    unittest.main()
